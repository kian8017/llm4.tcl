# AI Models Library for Tcl
# A simple TclOO-based library for interfacing with AI models
# Starting with OpenAI, designed to be extensible

package require http
package require tls
package require json
package require json::write

# Register HTTPS support
::http::register https 443 [list ::tls::socket -autoservername true]

namespace eval ::llm4 {
    variable version 0.0.1
    namespace export AIClient OpenAIClient
}

# Base class for all AI model clients
oo::class create ::llm4::AIClient {
    variable api_key
    variable base_url
    variable default_model
    variable timeout
    
    constructor {args} {
        set timeout 30000
        
        if {[llength $args] % 2 != 0} {
            error "Constructor arguments must be key-value pairs"
        }
        
        foreach {key value} $args {
            switch -exact -- $key {
                -api_key { set api_key $value }
                -model { set default_model $value }
                -timeout { set timeout $value }
                default {
                    error "Unknown option: $key"
                }
            }
        }
    }
    
    # Abstract method - subclasses must implement
    method send_request {messages args} {
        error "send_request method must be implemented by subclass"
    }
    
    method set_api_key {key} {
        set api_key $key
    }
    
    method get_api_key {} {
        if {[info exists api_key]} {
            return $api_key
        }
        return ""
    }
    
    method set_model {model} {
        set default_model $model
    }
    
    method get_model {} {
        if {[info exists default_model]} {
            return $default_model
        }
        return ""
    }
}

# OpenAI-specific client implementation
oo::class create ::llm4::OpenAIClient {
    superclass ::llm4::AIClient
    variable api_key base_url default_model timeout
    
    constructor {args} {
        # Set OpenAI defaults
        set base_url "https://api.openai.com/v1"
        set default_model "gpt-4.1-nano"
        
        # Check for API key in environment
        if {![dict exists $args -api_key] && [info exists ::env(OPENAI_API_KEY)]} {
            lappend args -api_key $::env(OPENAI_API_KEY)
        }
        
        next {*}$args
    }
    
    # Main method to send chat completion requests
    method send_request {messages args} {
        if {![info exists api_key] || $api_key eq ""} {
            error "API key not set. Use set_api_key or set OPENAI_API_KEY environment variable"
        }
        
        # Parse optional arguments
        set model $default_model
        set temperature 1.0
        set response_format ""
        
        foreach {key value} $args {
            switch -exact -- $key {
                -model { set model $value }
                -temperature { set temperature $value }
                -response_format { set response_format $value }
                default {
                    error "Unknown option: $key"
                }
            }
        }
        
        # Validate messages
        my validate_messages $messages
        
        # Build request
        set request_data [dict create \
            model $model \
            messages $messages \
            temperature $temperature \
        ]
        
        # Add response_format if provided
        if {$response_format ne ""} {
            dict set request_data response_format $response_format
        }
        
        # Convert to JSON
        set json_data [my build_request_json $request_data]
        
        # Set headers
        set headers [list \
            "Authorization" "Bearer $api_key" \
            "Content-Type" "application/json" \
        ]
        
        # Make request
        set url "${base_url}/chat/completions"
        
        try {
            set token [::http::geturl $url \
                -headers $headers \
                -query $json_data \
                -timeout $timeout]
            
            set status [::http::status $token]
            set http_code [::http::ncode $token]
            set response_data [::http::data $token]
            
            if {$status ne "ok"} {
                error "HTTP request failed: $status"
            }
            
            if {$http_code >= 400} {
                error "API request failed (HTTP $http_code): [my parse_error $response_data]"
            }
            
            return [my parse_response $response_data]
            
        } finally {
            if {[info exists token]} {
                ::http::cleanup $token
            }
        }
    }
    
    # Send a prompt (optionally with system message)
    method prompt {user_message args} {
        set system_message ""
        set filtered_args {}
        
        # Parse arguments to extract system message
        foreach {key value} $args {
            switch -exact -- $key {
                -system { set system_message $value }
                default { lappend filtered_args $key $value }
            }
        }
        
        # Build messages array
        set messages {}
        if {$system_message ne ""} {
            lappend messages [dict create role "system" content $system_message]
        }
        lappend messages [dict create role "user" content $user_message]
        
        set response [my send_request $messages {*}$filtered_args]
        
        # Check for refusal and throw error if present
        if {[dict exists $response refusal]} {
            error "Model refused request: [dict get $response refusal]"
        }
        
        # Return just the content
        return [dict get $response content]
    }
    
    # Send a prompt with structured output using JSON schema
    method prompt_structured {user_message schema args} {
        set system_message ""
        set filtered_args {}
        
        # Parse arguments to extract system message
        foreach {key value} $args {
            switch -exact -- $key {
                -system { set system_message $value }
                default { lappend filtered_args $key $value }
            }
        }
        
        # Build messages array
        set messages {}
        if {$system_message ne ""} {
            lappend messages [dict create role "system" content $system_message]
        }
        lappend messages [dict create role "user" content $user_message]
        
        # Convert schema to response_format
        set response_format [my schema_to_response_format $schema]
        
        set response [my send_request $messages -response_format $response_format {*}$filtered_args]
        
        # Check for refusal and throw error if present
        if {[dict exists $response refusal]} {
            error "Model refused request: [dict get $response refusal]"
        }
        
        # Check if structured data was parsed successfully
        if {![dict exists $response parsed]} {
            error "Failed to parse structured response: [dict get $response content]"
        }
        
        # Return just the parsed structured data
        return [dict get $response parsed]
    }
    
    # Validate messages format
    method validate_messages {messages} {
        if {![llength $messages]} {
            error "Messages list cannot be empty"
        }
        
        foreach message $messages {
            if {![dict exists $message role] || ![dict exists $message content]} {
                error "Each message must have 'role' and 'content' keys"
            }
            
            set role [dict get $message role]
            if {$role ni {system user assistant}} {
                error "Message role must be one of: system, user, assistant"
            }
        }
    }
    
    # Convert Tcl schema dict to OpenAI response_format structure
    method schema_to_response_format {schema} {
        # Validate required fields
        if {![dict exists $schema name]} {
            error "Schema must include a 'name' field"
        }
        
        if {![dict exists $schema schema]} {
            error "Schema must include a 'schema' field with the JSON schema definition"
        }
        
        set schema_name [dict get $schema name]
        set schema_def [dict get $schema schema]
        
        # Build response_format structure
        set response_format [dict create \
            type "json_schema" \
            json_schema [dict create \
                name $schema_name \
                strict true \
                schema $schema_def \
            ] \
        ]
        
        return $response_format
    }
    
    # Validate schema structure
    method validate_schema {schema} {
        if {![dict exists $schema name]} {
            error "Schema must include a 'name' field"
        }
        
        if {![dict exists $schema schema]} {
            error "Schema must include a 'schema' field"
        }
        
        set schema_def [dict get $schema schema]
        
        if {![dict exists $schema_def type]} {
            error "Schema definition must include a 'type' field"
        }
        
        return true
    }
    
    # Convert request data to JSON using json::write
    method build_request_json {request_data} {
        set json_pairs {}
        
        dict for {key value} $request_data {
            if {$key eq "messages"} {
                # Handle messages array
                set message_array {}
                foreach msg $value {
                    set msg_pairs {}
                    dict for {msg_key msg_value} $msg {
                        lappend msg_pairs $msg_key [::json::write string $msg_value]
                    }
                    lappend message_array [::json::write object {*}$msg_pairs]
                }
                lappend json_pairs $key [::json::write array {*}$message_array]
            } elseif {$key eq "response_format"} {
                # Handle response_format nested structure
                lappend json_pairs $key [my format_response_format_json $value]
            } elseif {[string is boolean $value]} {
                # Handle boolean values - use string since json::write doesn't have boolean
                if {$value} {
                    lappend json_pairs $key "true"
                } else {
                    lappend json_pairs $key "false"
                }
            } elseif {[string is double $value]} {
                # Handle numeric values - just use the value directly
                lappend json_pairs $key $value
            } else {
                # Handle string values
                lappend json_pairs $key [::json::write string $value]
            }
        }
        
        return [::json::write object {*}$json_pairs]
    }
    
    # Format response_format structure as JSON
    method format_response_format_json {response_format} {
        set rf_pairs {}
        
        dict for {key value} $response_format {
            if {$key eq "json_schema"} {
                # Handle json_schema nested object
                set js_pairs {}
                dict for {js_key js_value} $value {
                    if {$js_key eq "schema"} {
                        # Handle the actual JSON schema
                        lappend js_pairs $js_key [my format_schema_json $js_value]
                    } elseif {[string is boolean $js_value]} {
                        if {$js_value} {
                            lappend js_pairs $js_key "true"
                        } else {
                            lappend js_pairs $js_key "false"
                        }
                    } else {
                        lappend js_pairs $js_key [::json::write string $js_value]
                    }
                }
                lappend rf_pairs $key [::json::write object {*}$js_pairs]
            } else {
                lappend rf_pairs $key [::json::write string $value]
            }
        }
        
        return [::json::write object {*}$rf_pairs]
    }
    
    # Format JSON schema structure
    method format_schema_json {schema} {
        set schema_pairs {}
        
        dict for {key value} $schema {
            if {$key eq "properties"} {
                # Handle properties object
                set prop_pairs {}
                dict for {prop_key prop_value} $value {
                    lappend prop_pairs $prop_key [my format_schema_json $prop_value]
                }
                lappend schema_pairs $key [::json::write object {*}$prop_pairs]
            } elseif {$key eq "items"} {
                # Handle items (for arrays)
                lappend schema_pairs $key [my format_schema_json $value]
            } elseif {$key eq "required"} {
                # Handle required array
                set req_items {}
                foreach item $value {
                    lappend req_items [::json::write string $item]
                }
                lappend schema_pairs $key [::json::write array {*}$req_items]
            } elseif {[string is boolean $value]} {
                if {$value} {
                    lappend schema_pairs $key "true"
                } else {
                    lappend schema_pairs $key "false"
                }
            } elseif {[string is integer $value]} {
                lappend schema_pairs $key $value
            } else {
                lappend schema_pairs $key [::json::write string $value]
            }
        }
        
        return [::json::write object {*}$schema_pairs]
    }
    
    # Parse API response
    method parse_response {response_data} {
        set response_dict [::json::json2dict $response_data]
        
        # Extract the message content
        set choices [dict get $response_dict choices]
        set first_choice [lindex $choices 0]
        set message [dict get $first_choice message]
        set content [dict get $message content]
        
        # Check for refusal (structured outputs safety feature)
        set refusal ""
        if {[dict exists $message refusal]} {
            set refusal [dict get $message refusal]
            # Treat null/empty as no refusal
            if {$refusal eq "null" || $refusal eq ""} {
                set refusal ""
            }
        }
        
        # Try to parse JSON content for structured outputs
        set parsed_content ""
        if {$refusal eq "" && $content ne ""} {
            try {
                set parsed_content [::json::json2dict $content]
            } on error {} {
                # Content is not JSON, leave as string
            }
        }
        
        set result [dict create \
            content $content \
            model [dict get $response_dict model] \
            usage [dict get $response_dict usage] \
        ]
        
        # Add refusal if present
        if {$refusal ne ""} {
            dict set result refusal $refusal
        }
        
        # Add parsed content if successfully parsed
        if {$parsed_content ne ""} {
            dict set result parsed $parsed_content
        }
        
        return $result
    }
    
    # Parse error response
    method parse_error {response_data} {
        try {
            set error_dict [::json::json2dict $response_data]
            if {[dict exists $error_dict error message]} {
                return [dict get $error_dict error message]
            }
        } on error {} {
            # Fall back to raw response
        }
        return $response_data
    }
}

# Convenience procedure
proc ::llm4::openai {args} {
    return [::llm4::OpenAIClient new {*}$args]
}

package provide llm4 $::llm4::version

# Example usage:
#
# set client [::llm4::openai]
# set response [$client prompt "What is the capital of France?"]
# puts [dict get $response content]
#
# set response [$client prompt "Explain TCP/IP" -system "You are a helpful networking expert"]
# puts [dict get $response content]

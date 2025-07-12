# AI Models Library for Tcl
# A simple TclOO-based library for interfacing with AI models
# Starting with OpenAI, designed to be extensible

package require http
package require tls
package require json

# Register HTTPS support
::http::register https 443 [list ::tls::socket -autoservername true]

namespace eval ::aimodels {
    variable version 0.0.1
    namespace export AIClient OpenAIClient
}

# Base class for all AI model clients
oo::class create ::aimodels::AIClient {
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
oo::class create ::aimodels::OpenAIClient {
    superclass ::aimodels::AIClient
    
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
        
        foreach {key value} $args {
            switch -exact -- $key {
                -model { set model $value }
                -temperature { set temperature $value }
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
        
        # Convert to JSON
        set json_data [my dict_to_json $request_data]
        
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
        
        return [my send_request $messages {*}$filtered_args]
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
    
    # Convert dict to JSON string
    method dict_to_json {d} {
        set pairs {}
        dict for {key value} $d {
            if {[string is list $value] && [llength $value] > 0} {
                # Handle message arrays
                set items {}
                foreach item $value {
                    lappend items [my dict_to_json $item]
                }
                lappend pairs "\"$key\":\[[join $items ,]\]"
            } elseif {[string is dict $value]} {
                # Handle nested objects
                lappend pairs "\"$key\":[my dict_to_json $value]"
            } elseif {[string is double $value]} {
                lappend pairs "\"$key\":$value"
            } else {
                # Escape quotes in strings
                set escaped [string map {\" \\\" \\ \\\\} $value]
                lappend pairs "\"$key\":\"$escaped\""
            }
        }
        return "\{[join $pairs ,]\}"
    }
    
    # Parse API response
    method parse_response {response_data} {
        set response_dict [::json::json2dict $response_data]
        
        # Extract the message content
        set choices [dict get $response_dict choices]
        set first_choice [lindex $choices 0]
        set content [dict get $first_choice message content]
        
        return [dict create \
            content $content \
            model [dict get $response_dict model] \
            usage [dict get $response_dict usage] \
        ]
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
proc ::aimodels::openai {args} {
    return [::aimodels::OpenAIClient new {*}$args]
}

package provide aimodels $::aimodels::version

# Example usage:
#
# set client [::aimodels::openai]
# set response [$client prompt "What is the capital of France?"]
# puts [dict get $response content]
#
# set response [$client prompt "Explain TCP/IP" -system "You are a helpful networking expert"]
# puts [dict get $response content]

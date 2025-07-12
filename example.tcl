#!/usr/bin/env tclsh

# Simple example script using the llm4 library
source llm4.tcl

# Create an OpenAI client
set client [::llm4::openai]

# Query with system message
puts "Asking about TCP/IP with pirate context..."
set response [$client prompt "Explain TCP/IP in one sentence" -system "Talk like a pirate"]
puts "Response: $response"

puts "\n--- Structured Output Example ---"

# Define a schema for structured output
set analysis_schema {
    name "text_analysis"
    schema {
        type "object"
        properties {
            sentiment {type "string"}
            confidence {type "number"}
            key_topics {
                type "array"
                items {type "string"}
            }
            word_count {type "integer"}
        }
        required {sentiment confidence key_topics word_count}
        additionalProperties false
    }
}

# Query with structured output
puts "Analyzing text with structured output..."
try {
    set data [$client prompt_structured "Analyze this text: 'I love programming in Tcl! It's such a powerful and elegant language.'" $analysis_schema]
    puts "Sentiment: [dict get $data sentiment]"
    puts "Confidence: [dict get $data confidence]"
    puts "Key Topics: [join [dict get $data key_topics] {, }]"
    puts "Word Count: [dict get $data word_count]"
} on error {msg} {
    puts "Error: $msg"
}

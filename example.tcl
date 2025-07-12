#!/usr/bin/env tclsh

# Simple example script using the llm4 library
source llm4.tcl

# Create an OpenAI client
set client [::llm4::openai]

# Query with system message
puts "Asking about TCP/IP with pirate context..."
set response [$client prompt "Explain TCP/IP in one sentence" -system "Talk like a pirate"]
puts "Response: [dict get $response content]"

#!/usr/bin/env tclsh

# Simple example script using the aimodels library
source main.tcl

# Create an OpenAI client
set client [::aimodels::openai]

# Simple query
puts "Asking: What is 2+2?"
set response [$client prompt "What is 2+2?"]
puts "Response: [dict get $response content]"
puts ""

# Query with system message
puts "Asking about TCP/IP with networking expert context..."
set response [$client prompt "Explain TCP/IP in one sentence" -system "You are a helpful networking expert"]
puts "Response: [dict get $response content]"
# llm4

A simple TclOO-based library for interfacing with AI models, starting with OpenAI.

## Features

- **TclOO-based architecture**: Clean object-oriented design with extensible base class
- **OpenAI API integration**: Full support for chat completions with GPT models
- **Structured outputs**: Support for JSON schema-based structured responses
- **Environment variable integration**: Automatically uses `OPENAI_API_KEY` if available
- **Error handling**: Comprehensive HTTP and API error detection with meaningful messages
- **Multiple interaction modes**: Simple prompts, system messages, and structured data extraction

## Installation

This is a pure Tcl library with no build system required. Simply source the main file:

```tcl
source llm4.tcl
```

### Dependencies

- `http` - HTTP client functionality  
- `tls` - HTTPS support
- `json` - JSON parsing for API responses
- `json::write` - JSON serialization for API requests

**Note:** If you have [tcllib](https://core.tcl-lang.org/tcllib/doc/trunk/embedded/index.md) installed, all dependencies are covered.

## Quick Start

### Basic Usage

```tcl
# Source the library
source llm4.tcl

# Create an OpenAI client (uses OPENAI_API_KEY environment variable)
set client [::llm4::openai]

# Simple prompt
set response [$client prompt "What is the capital of France?"]
puts $response
```

### With System Message

```tcl
set response [$client prompt "Explain TCP/IP" -system "You are a helpful networking expert"]
puts $response
```

### Structured Output

```tcl
# Define a JSON schema
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

# Get structured data
set data [$client prompt_structured "Analyze this text: 'I love programming!'" $analysis_schema]
puts "Sentiment: [dict get $data sentiment]"
puts "Confidence: [dict get $data confidence]"
```

## API Reference

### Class Hierarchy

```
::llm4::AIClient (base class)
└── ::llm4::OpenAIClient (OpenAI implementation)
```

### AIClient Base Class

Abstract base class defining the interface for AI model clients.

#### Constructor Options

- `-api_key` - API key for authentication
- `-model` - Default model to use for requests
- `-timeout` - Request timeout in milliseconds (default: 30000)

#### Methods

- `set_api_key {key}` - Set the API key
- `get_api_key {}` - Get the current API key  
- `set_model {model}` - Set the default model
- `get_model {}` - Get the current default model
- `send_request {messages args}` - Abstract method implemented by subclasses

### OpenAIClient

OpenAI-specific implementation of AIClient.

#### Constructor

```tcl
set client [::llm4::OpenAIClient new ?options?]
# or use the convenience proc:
set client [::llm4::openai ?options?]
```

**Options:**
- `-api_key` - OpenAI API key (defaults to `OPENAI_API_KEY` environment variable)
- `-model` - Model to use (default: "gpt-4.1-nano")
- `-timeout` - Request timeout in milliseconds (default: 30000)

#### Methods

##### `send_request {messages ?options?}`

Low-level method for sending chat completion requests with full message control.

**Parameters:**
- `messages` - List of message dictionaries with `role` and `content` keys
- `?options?` - Optional arguments:
  - `-model` - Override default model
  - `-temperature` - Sampling temperature (0.0-2.0)
  - `-response_format` - Response format specification for structured outputs

**Returns:** Dictionary with response data including `content`, `model`, and `usage`

##### `prompt {user_message ?options?}`

High-level convenience method for single user prompts.

**Parameters:**
- `user_message` - The user's prompt text
- `?options?` - Optional arguments:
  - `-system` - System message to include
  - `-model` - Override default model
  - `-temperature` - Sampling temperature

**Returns:** String containing the assistant's response

##### `prompt_structured {user_message schema ?options?}`

Send a prompt with structured output using JSON schema.

**Parameters:**
- `user_message` - The user's prompt text
- `schema` - Dictionary with `name` and `schema` keys defining the JSON schema
- `?options?` - Optional arguments:
  - `-system` - System message to include
  - `-model` - Override default model
  - `-temperature` - Sampling temperature

**Returns:** Dictionary containing the parsed structured data

## Configuration

### Environment Variables

- `OPENAI_API_KEY` - Your OpenAI API key (automatically detected)

### Models

The default model is `gpt-4.1-nano`. You can override this by:

```tcl
# At client creation
set client [::llm4::openai -model "gpt-4"]

# Or per request
set response [$client prompt "Hello" -model "gpt-3.5-turbo"]
```

## Examples

### Running the Example

```bash
# Set your API key
export OPENAI_API_KEY="your-api-key-here"

# Run the example
tclsh example.tcl
```

### Interactive Usage

```bash
tclsh
% source llm4.tcl
% set client [::llm4::openai]
% set response [$client prompt "Hello"]
% puts $response
```

## Error Handling

The library provides comprehensive error handling:

- **Missing API key**: Clear error message with instructions
- **HTTP errors**: Network and HTTP status code errors
- **API errors**: OpenAI API error messages
- **Validation errors**: Message format and parameter validation
- **Model refusals**: Structured output safety refusals

## Version

Current version: 0.0.1

## License

MIT License - see LICENSE file for details.

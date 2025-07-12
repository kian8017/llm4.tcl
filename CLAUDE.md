# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

This is a pure Tcl library with no build system. To run:

```bash
# Run the example
tclsh example.tcl

# Test the library directly
tclsh
% source llm4.tcl
% set client [::llm4::openai]
% set response [$client prompt "Hello"]
```

## Code Architecture

This repository provides `llm4`, a TclOO-based library for interfacing with AI models, starting with OpenAI.

### Core Components

- **`llm4.tcl`**: Main library file containing the complete implementation
- **`example.tcl`**: Simple usage example demonstrating the API

### Class Hierarchy

```
::llm4::AIClient (base class)
└── ::llm4::OpenAIClient (OpenAI implementation)
```

**AIClient** (`llm4.tcl:18-69`): Abstract base class defining the interface for AI model clients
- Common configuration: API key, model, timeout
- Abstract `send_request` method that subclasses must implement

**OpenAIClient** (`llm4.tcl:72-251`): OpenAI-specific implementation
- Handles OpenAI API authentication and request formatting
- Main methods:
  - `send_request`: Low-level API interaction with full message control
  - `prompt`: High-level convenience method for single user prompts with optional system messages
- Built-in JSON serialization for API requests
- Response parsing and error handling

### Key Design Patterns

- **Environment variable integration**: Automatically uses `OPENAI_API_KEY` if available
- **Argument validation**: Methods validate message format and required parameters
- **Error handling**: Comprehensive HTTP and API error detection with meaningful messages
- **Convenience factory**: `::llm4::openai` proc for easy client instantiation

### Dependencies

- `http`: HTTP client functionality
- `tls`: HTTPS support
- `json`: JSON parsing for API responses

The library registers HTTPS support on initialization and provides a complete OpenAI chat completion interface through TclOO objects.
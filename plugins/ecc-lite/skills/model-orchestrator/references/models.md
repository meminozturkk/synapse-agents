# Model Capabilities & Routing Reference

## 1. Gemini Models (Antigravity Native)

| Model | Strengths | Ideal Use Cases | Context Window |
| :--- | :--- | :--- | :--- |
| **Gemini 4 Argon** | Deep architectural reasoning, multi-file code refactoring, complex bug diagnosis | System architecture, complex debugging, intricate planning | 1M+ tokens |
| **Gemini 3.8 Flash** | Ultra-low latency, massive context comprehension, fast tool execution | Rapid search, multi-file codebase indexing, quick edits | 1M+ tokens |
| **Subagents (pro / flash / flash_lite)** | Autonomous execution in isolated contexts | Independent research, test generation, file operations | Variable |

## 2. NVIDIA NIM Models (Serverless API)

| Model Name / ID | Primary Strengths | Ideal Subagent Role | Speed / Latency |
| :--- | :--- | :--- | :--- |
| **`meta/llama-3.2-11b-vision-instruct`** | Concise instruction following, high throughput, fast code checks | Fast reviewer, syntax validator, prompt refiner, translation | Very Fast (<2s) |
| **`meta/llama-3.2-90b-vision-instruct`** | Deep semantic reasoning, multimodal vision, high-complexity problem solving | Senior reviewer, second-opinion architect, edge-case hunter | Moderate |
| **`meta/codellama-70b`** | Dedicated Python/C++/Rust code generation, algorithm structuring | Core algorithm generation, performance optimization | Fast-Moderate |
| **`deepseek-ai/deepseek-v4.1-flash`** | Math, logic puzzles, algorithmic reasoning | Complex algorithmic design, math proofs | Very Fast |
| **`nvidia/llama-3.1-nemotron-70b-instruct`** | Instruction following, detailed step-by-step reasoning | Test plan formulation, protocol auditing | Moderate |
| **`nvidia/nemotron-4-340b-instruct`** | Ultra-scale parameter depth, comprehensive knowledge synthesis | Flagship synthesis, high-stakes decision analysis | Deep / Slower |

## 3. Communication Protocols

* **NVIDIA MCP Server**: `nvidia-nim` (`ask_nvidia`, `list_nvidia_models`)
* **Terminal CLI**: `nv-chat -m <model> "<prompt>"`
* **Local Gateway**: `http://localhost:4000` (LiteLLM Proxy - OpenAI & Anthropic Wire Compatible)

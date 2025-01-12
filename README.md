# ABAP LLM Agent Framework

## Release Status
**Preview** - This is a development preview, see it as my personal ideation / proof of concept version. Everything might change, interface features might be missing, probably many bugs or it might not even activate.\
Nevertheless any feedback and discussions are highly welcome to influence the next steps early. Note that pull requests likely make no sense at the current state and issues are expected but feel free to open feature requests or discussions.

## Documentation
Currently none, check the llm_agent_tests repo on how to use it.

## Overview
The Agent Framework aims at providing a simple way to use LLM features in ABAP. It builds upon the LLM Client. Running on 7.52 and above but not ABAP Cloud.\
Planned features:
- Multi-Step Agents capable of using default and custom (user provided) tools
- Agents can either output text or abap data structures (as json schema) via Structured Outputs
- Manager Agents for multi-agent workflows
- Full step trace (optionally saved to the database)

Considered additional features:
- Planning mode optionally using a second LLM model (e.g. plan with o1-mini and execute via 4o-mini)
- ReAct based flow instead of pure function calling

Some more things I am not yet sure how I should implement them in this constrained environment but we'll see.
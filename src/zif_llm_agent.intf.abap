"! <p class="shorttext synchronized" lang="en">Agent Interface</p>
" ABAP interfaces are similar to Java interfaces but start with Z/Y for custom code
" and use the suffix _agent for better searchability
INTERFACE zif_llm_agent
  PUBLIC.  " PUBLIC makes interface visible to all (like public in Java)

  "! Collection of agents
  " TYPES in ABAP is like declaring custom types in Java
  " REF TO is similar to Java references/pointers
  " STANDARD TABLE is like a Java List/ArrayList
  TYPES agents TYPE STANDARD TABLE OF REF TO zif_llm_agent WITH EMPTY KEY.
  
  TYPES:
    "! Agent status - BEGIN OF/END OF creates a structure (like a Java class with fields)
    BEGIN OF status,
      " abap_bool is ABAP's boolean type (similar to Boolean in Java)
      is_running TYPE abap_bool,  " Indicates if agent is currently executing
      is_done    TYPE abap_bool,  " True when agent finished its task
      has_error  TYPE abap_bool,  " Error flag
      message    TYPE string,      " Status/error message
    END OF status.
  
  TYPES:
    "! Memory entry structure for tracking agent activities
    BEGIN OF memory_entry,
      timestamp TYPE timestamp,  " When entry was created
      msg       TYPE zllm_msg,  " The actual message content
    END OF memory_entry,
    "! Memory entries collection (like List<MemoryEntry> in Java)
    memory_entries TYPE STANDARD TABLE OF memory_entry WITH EMPTY KEY.

  " CONSTANTS in ABAP are like static final fields in Java
  " BEGIN OF creates a structure to group related constants
  CONSTANTS:
    BEGIN OF memory_types,
      " String values to identify different memory entry types
      message     TYPE string VALUE 'MESSAGE',
      tool_call   TYPE string VALUE 'TOOL_CALL', 
      tool_result TYPE string VALUE 'TOOL_RESULT',
    END OF memory_types.

  "! <p class="shorttext synchronized">Executes the agent's main task</p>
  " METHODS declares interface methods like in Java
  " IMPORTING is for input parameters (like regular Java parameters)
  " RETURNING is for return values (like return type in Java)
  " OPTIONAL means parameter can be omitted (like @Nullable in Java)
  " RAISING declares exceptions that can be thrown (like throws in Java)
  METHODS execute
    IMPORTING prompt        TYPE string OPTIONAL
    RETURNING VALUE(result) TYPE zllm_response  
    RAISING   zcx_llm_agent_error.

  "! <p class="shorttext synchronized">Gets current agent status</p>
  "! @parameter result | <p class="shorttext synchronized">Current status</p>
  METHODS get_status
    RETURNING VALUE(result) TYPE status.

  "! <p class="shorttext synchronized">Sets the agent's context</p>
  "! @parameter messages | <p class="shorttext synchronized">Context messages</p>
  METHODS set_context
    IMPORTING !messages TYPE zllm_msgs.

  "! <p class="shorttext synchronized">Gets the agent's context</p>
  "! @parameter result | <p class="shorttext synchronized">Current context</p>
  METHODS get_context
    RETURNING VALUE(result) TYPE zllm_msgs
    RAISING   zcx_llm_agent_error.

  "! <p class="shorttext synchronized">Gets agent memory</p>
  "! @parameter result | <p class="shorttext synchronized">Memory entries</p>
  METHODS get_memory
    RETURNING VALUE(result) TYPE memory_entries.

  "! <p class="shorttext synchronized">Add a tool to the agent</p>
  "! @parameter tool                | <p class="shorttext synchronized">Tool to add</p>
  "! @raising   zcx_llm_agent_error | <p class="shorttext synchronized">Tool error</p>
  METHODS add_tool
    IMPORTING tool TYPE REF TO zif_llm_tool
    RAISING   zcx_llm_agent_error.

  "! <p class="shorttext synchronized">Add multiple tools</p>
  "! @parameter tools               | <p class="shorttext synchronized">Tools to add</p>
  "! @raising   zcx_llm_agent_error | <p class="shorttext synchronized">Tool error</p>
  METHODS add_tools
    IMPORTING tools TYPE zllm_tools
    RAISING   zcx_llm_agent_error.

  "! <p class="shorttext synchronized">Get configured tools</p>
  "! @parameter result | <p class="shorttext synchronized">Available tools</p>
  METHODS get_tools
    RETURNING VALUE(result) TYPE zllm_tools.

  "! <p class="shorttext synchronized">Get options reference</p>
  "!
  "! @parameter result | <p class="shorttext synchronized">Option reference</p>
  METHODS get_options
    RETURNING VALUE(result) TYPE REF TO zif_llm_options.

ENDINTERFACE.

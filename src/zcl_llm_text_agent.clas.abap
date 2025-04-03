" Concrete implementation of LLM agent for text processing
CLASS zcl_llm_text_agent DEFINITION
  PUBLIC
  INHERITING FROM zcl_llm_agent_base  " Like extends in Java
  CREATE PUBLIC.

  PUBLIC SECTION.
    " Static constructor (like static initializer block in Java)  
    CLASS-METHODS class_constructor.

    " Instance constructor with default parameter values
    METHODS constructor
      IMPORTING
        " DEFAULT sets default value (like default parameters in Java)
        model TYPE zllm_model DEFAULT 'llama3.2'
        tools TYPE zllm_tools OPTIONAL
      RAISING
        zcx_llm_agent_error.

    " REDEFINITION indicates method override (like @Override in Java)
    METHODS zif_llm_agent~execute REDEFINITION.

  PROTECTED SECTION.
    " Implements abstract method from base class
    METHODS initialize REDEFINITION.

  PRIVATE SECTION.
    " CLASS-DATA is static variable (like static field in Java)
    CLASS-DATA system_prompt TYPE string.

ENDCLASS.

CLASS zcl_llm_text_agent IMPLEMENTATION.

  METHOD constructor.
    TRY.
        " Factory call to get LLM client
        DATA(client) = zcl_llm_factory=>get_client( model ).
      CATCH zcx_llm_authorization INTO DATA(error).
        " Error handling
    ENDTRY.
    
    " Call parent constructor (like super() in Java)
    super->constructor( client = client tools = tools ).
    initialize( ).
  ENDMETHOD.

  METHOD zif_llm_agent~execute.
    " Execute with input text as prompt
    result = super->execute( prompt ).
  ENDMETHOD.

  METHOD initialize.
    " Add system prompt to agent memory
    add_to_memory_internal( value #(
        msg-role    = client->role_system
        msg-content = system_prompt ) ).
  ENDMETHOD.

  METHOD class_constructor.
    " & concatenates strings in ABAP (like + in Java)
    system_prompt =
        `You are a helpful expert assistant that happily solves the given task. ` &
        `Your tone is business professional, concise and precise. ` &
        `If tools are available, use them when appropriate to gather information needed for your response.`.
  ENDMETHOD.

ENDCLASS.

CLASS zcl_llm_agent_base DEFINITION
  PUBLIC
  ABSTRACT  " Abstract like in Java, cannot be instantiated directly
  CREATE PUBLIC.

  PUBLIC SECTION.  " Like public visibility in Java
    " Interfaces must be explicitly implemented in ABAP (no implements keyword)
    INTERFACES zif_llm_agent.
    INTERFACES zif_llm_agent_internal.

    " Constructor method (like Java constructor)
    " IMPORTING parameters are like constructor parameters in Java
    METHODS constructor
      IMPORTING 
        !client TYPE REF TO zif_llm_client  " ! means required parameter
        tools   TYPE zllm_tools
      RAISING zcx_llm_agent_error.

    " ALIASES creates method shortcuts (no Java equivalent)
    " This allows calling methods directly on the class instead of through interface
    ALIASES execute     FOR zif_llm_agent~execute.
    ALIASES get_context FOR zif_llm_agent~get_context.
    ALIASES get_memory  FOR zif_llm_agent~get_memory.
    ALIASES get_status  FOR zif_llm_agent~get_status.
    ALIASES set_context FOR zif_llm_agent~set_context.
    ALIASES add_tool    FOR zif_llm_agent~add_tool.
    ALIASES add_tools   FOR zif_llm_agent~add_tools.
    ALIASES get_tools   FOR zif_llm_agent~get_tools.
    ALIASES get_options FOR zif_llm_agent~get_options.

  PROTECTED SECTION.  " Like protected in Java, visible to subclasses
    " Instance variables (like private fields in Java)
    DATA client         TYPE REF TO zif_llm_client.
    DATA chat_request   TYPE REF TO zif_llm_chat_request.
    DATA memory         TYPE zif_llm_agent=>memory_entries.
    DATA status         TYPE zif_llm_agent=>status.
    DATA max_iterations TYPE i VALUE 5.  " i is integer type, with default value
    DATA tools          TYPE zllm_tools.

    " Abstract method that must be implemented by concrete classes
    METHODS initialize ABSTRACT
      RAISING zcx_llm_agent_error.

    " Helper methods for subclasses
    METHODS create_chat_request
      RETURNING VALUE(result) TYPE REF TO zif_llm_chat_request.

    METHODS prepare_messages
      RETURNING VALUE(result) TYPE zllm_msgs
      RAISING   zcx_llm_agent_error.

    METHODS process_structured_output
      IMPORTING !response     TYPE zllm_response
      RETURNING VALUE(result) TYPE zllm_response
      RAISING   zcx_llm_agent_error.

    METHODS process_tool_calls
      IMPORTING !response     TYPE zllm_response
      RETURNING VALUE(result) TYPE zllm_response
      RAISING   zcx_llm_agent_error.

    METHODS:
      add_to_memory_internal
        IMPORTING
          memory TYPE zif_llm_agent=>memory_entry.

  PRIVATE SECTION.  " Like private in Java
ENDCLASS.

" Implementation part (like class body in Java)
CLASS zcl_llm_agent_base IMPLEMENTATION.

  METHOD constructor.
    " me-> is like this. in Java
    me->client = client.
    me->tools = tools.
    " VALUE #( ) is a constructor expression for structures
    status = VALUE #( is_running = abap_false
                     is_done    = abap_false
                     has_error  = abap_false ).
  ENDMETHOD.

  METHOD zif_llm_agent~execute.
    " DATA declares local variables (like local vars in Java)
    DATA error TYPE REF TO zcx_llm_agent_error.

    " Start execution
    status-is_running = abap_true.  " - accesses structure fields
    status-is_done = abap_false.

    TRY.  " Like try in Java
        chat_request = create_chat_request( ).

        " IS NOT INITIAL checks for non-null (like != null in Java) 
        IF prompt IS NOT INITIAL.
          " Add user message to memory
          add_to_memory_internal( 
            VALUE #( msg-role    = client->role_user
                    msg-content = prompt ) ).
        ENDIF.

        " Prepare messages from memory
        DATA(messages) = prepare_messages( ).
        chat_request->add_messages( messages ).
        chat_request->options( )->set_temperature( '0.1' ).

        " Execute chat request
        result = client->chat( chat_request ).

        IF result-success = abap_false.
          RAISE EXCEPTION NEW zcx_llm_agent_error( textid = VALUE scx_t100key( msgid = 'ZLLM_AGENT'
                                                                               msgno = '001'  " Chat execution failed
                                                                               attr1 = result-error-error_text ) ).
        ENDIF.

        " Process response
        result = zif_llm_agent_internal~process_response( result ).

        IF lines( result-choice-tool_calls ) = 0.
          status-is_done = abap_true.
        ENDIF.

      CLEANUP.  " Always executed (like finally in Java)
        status-is_running = abap_false.
    ENDTRY.

    " WHILE loop like in Java
    DATA(iteration) = 1.  " DATA() infers type (like var in Java)
    WHILE status-is_done = abap_false.
      " Next execution
      result = client->chat( chat_request ).
      IF result-success = abap_false.
        RAISE EXCEPTION NEW zcx_llm_agent_error( textid = VALUE scx_t100key( msgid = 'ZLLM_AGENT'
                                                                             msgno = '001'  " Chat execution failed
                                                                             attr1 = result-error-error_text ) ).
      ENDIF.

      " Process response
      result = zif_llm_agent_internal~process_response( result ).

      IF lines( result-choice-tool_calls ) = 0 OR iteration >= max_iterations.
        status-is_done = abap_true.
        IF iteration >= max_iterations.
          result-success = abap_false.
          result-error-error_text = `Max iterations reached`.
          result-choice-message-content = result-error-error_text.
        ENDIF.
      ELSE.
        iteration = iteration + 1.
      ENDIF.

    ENDWHILE.

    " Error handling
    IF error IS NOT INITIAL.
      status-has_error = abap_true. 
      status-message = error->get_text( ).
      RAISE EXCEPTION error.  " Like throw in Java
    ENDIF.
  ENDMETHOD.

  METHOD prepare_messages.
    LOOP AT memory ASSIGNING FIELD-SYMBOL(<entry>).
      APPEND VALUE #( role    = <entry>-msg-role
                      content = <entry>-msg-content
                      name    = <entry>-msg-name
                      tool_call_id = <entry>-msg-tool_call_id
                      tool_calls = <entry>-msg-tool_calls
                       ) TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD zif_llm_agent~get_context.
    result = prepare_messages( ).
  ENDMETHOD.

  METHOD zif_llm_agent~get_memory.
    result = memory.
  ENDMETHOD.

  METHOD zif_llm_agent~get_status.
    result = status.
  ENDMETHOD.

  METHOD zif_llm_agent~set_context.
    CLEAR memory.
    LOOP AT messages ASSIGNING FIELD-SYMBOL(<message>).
      add_to_memory_internal( VALUE #( msg = <message> ) ).
    ENDLOOP.
  ENDMETHOD.

  METHOD zif_llm_agent_internal~add_to_memory.
    INSERT entry INTO TABLE memory.
  ENDMETHOD.

  METHOD add_to_memory_internal.
    zif_llm_agent_internal~add_to_memory( memory ).
  ENDMETHOD.

  METHOD zif_llm_agent_internal~can_proceed.
    result = xsdbool( lines( memory ) < max_iterations AND status-has_error = abap_false ).
  ENDMETHOD.

  METHOD zif_llm_agent_internal~prepare_next_iteration.
    " To be implemented by concrete classes if needed
  ENDMETHOD.

  METHOD process_structured_output.
    result = response.
  ENDMETHOD.

  METHOD zif_llm_agent~add_tool.
    INSERT tool INTO TABLE tools.
  ENDMETHOD.

  METHOD zif_llm_agent~add_tools.
    APPEND LINES OF tools TO me->tools.
  ENDMETHOD.

  METHOD zif_llm_agent~get_tools.
    result = tools.
  ENDMETHOD.

  METHOD create_chat_request.
    result = client->new_request( ).

    " Add configured tools to request
    IF tools IS NOT INITIAL.
      result->add_tools( tools       = tools
                         tool_choice = zif_llm_chat_request=>tool_choice_auto ).
    ENDIF.
  ENDMETHOD.

  METHOD zif_llm_agent_internal~process_response.
    result = response.

    " Process any tool calls in the response
    IF response-choice-tool_calls IS NOT INITIAL.
      result = process_tool_calls( response ).
    ENDIF.

    " Add assistant's response to memory
    add_to_memory_internal( VALUE #( msg-role = client->role_assistant
                            msg-content = response-choice-message-content
                            msg-tool_calls = response-choice-message-tool_calls
                            msg-tool_call_id = response-choice-message-tool_call_id ) ).
  ENDMETHOD.

  METHOD process_tool_calls.
    result = response.

    LOOP AT response-choice-tool_calls ASSIGNING FIELD-SYMBOL(<tool_call>).
      " Add tool calls to request for context
      chat_request->add_tool_choices( response-choice-tool_calls ).
      TRY.
          " Find matching tool
          DATA matching_tool TYPE REF TO zif_llm_tool.
          LOOP AT tools ASSIGNING FIELD-SYMBOL(<configured_tool>).
            IF <configured_tool>->get_tool_details( )-name = <tool_call>-function-name.
              matching_tool = <configured_tool>.
              EXIT.
            ENDIF.
          ENDLOOP.

          IF matching_tool IS INITIAL.
            RAISE EXCEPTION NEW zcx_llm_agent_error( textid = VALUE scx_t100key( msgid = 'ZLLM_AGENT'
                                                                                 msgno = '002'  " Tool not found: &1
                                                                                 attr1 = <tool_call>-function-name ) ).
          ENDIF.

          " Execute the tool with the provided arguments
          ASSIGN <tool_call>-function-arguments->* TO FIELD-SYMBOL(<tool_args>).
          IF sy-subrc = 0.
            matching_tool->execute( data         = REF #( <tool_args> )
                                    tool_call_id = <tool_call>-id ).
          ENDIF.

          add_to_memory_internal( VALUE #( msg-role         = zif_llm_client=>role_tool
                                           msg-tool_call_id = <tool_call>-id
                                           msg-content      = zcl_llm_common=>to_json(
                                                                  data = matching_tool->get_result( ) ) ) ).

          " Add tool result to chat request
          " TOOD - do we need this? Probably we should change the whole logic to avoid the memory and instead use chats
          chat_request->add_tool_result( matching_tool ).

        CATCH zcx_llm_agent_error INTO DATA(error).
          " Log error but continue with other tools
          add_to_memory_internal(
              VALUE #( msg-role    = client->role_tool
                       msg-content = |Error executing { <tool_call>-function-name }: { error->get_text( ) }|
                       msg-name    = <tool_call>-function-name ) ).
      ENDTRY.
    ENDLOOP.

    " Disable tool usage for the next request
    " chat_request->set_tool_choice( zif_llm_chat_request=>tool_choice_none ).
  ENDMETHOD.

  METHOD zif_llm_agent_internal~execute_tool.
    " Find matching tool
    DATA matching_tool TYPE REF TO zif_llm_tool.

    LOOP AT tools ASSIGNING FIELD-SYMBOL(<configured_tool>).
      IF <configured_tool>->get_tool_details( )-name = tool_call-name.
        matching_tool = <configured_tool>.
        EXIT.
      ENDIF.
    ENDLOOP.

    IF matching_tool IS INITIAL.
      RAISE EXCEPTION NEW zcx_llm_agent_error( textid = VALUE scx_t100key( msgid = 'ZLLM_AGENT'
                                                                           msgno = '002'  " Tool not found: &1
                                                                           attr1 = tool_call-name ) ).
    ENDIF.

    " Execute the tool
    TRY.
        " Create the data reference for the tool call
        DATA ref_data TYPE REF TO data.
        CREATE DATA ref_data TYPE HANDLE tool_call-parameters-data_desc.
        " TODO: variable is assigned but never used (ABAP cleaner)
        ASSIGN ref_data->* TO FIELD-SYMBOL(<tool_data>).

        " Execute tool with the prepared data reference
        result = VALUE #( name = tool_call-name
                          data = matching_tool->execute( data         = ref_data
                                                         tool_call_id = tool_call-name )-data ).
      CATCH cx_root INTO DATA(error).
        RAISE EXCEPTION NEW zcx_llm_agent_error( textid   = VALUE scx_t100key( msgid = 'ZLLM_AGENT'
                                                                               msgno = '003'  " Tool execution failed: &1
                                                                               attr1 = error->get_text( ) )
                                                 previous = error ).
    ENDTRY.
  ENDMETHOD.

  METHOD zif_llm_agent~get_options.
    result = chat_request->options( ).
  ENDMETHOD.

ENDCLASS.

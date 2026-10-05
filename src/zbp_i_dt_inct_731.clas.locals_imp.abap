CLASS lhc_Incident DEFINITION
  INHERITING FROM cl_abap_behavior_handler.

  PUBLIC SECTION.

    CONSTANTS:
      BEGIN OF mc_status,
        open        TYPE zdt_inct_731-status VALUE 'OP',
        in_progress TYPE zdt_inct_731-status VALUE 'IP',
        pending     TYPE zdt_inct_731-status VALUE 'PE',
        completed   TYPE zdt_inct_731-status VALUE 'CO',
        closed      TYPE zdt_inct_731-status VALUE 'CL',
        canceled    TYPE zdt_inct_731-status VALUE 'CN',
      END OF mc_status.

  PRIVATE SECTION.

    METHODS get_instance_features
      FOR INSTANCE FEATURES
      IMPORTING
        keys REQUEST requested_features
        FOR Incident
      RESULT result.

    METHODS get_instance_authorizations
      FOR INSTANCE AUTHORIZATION
      IMPORTING
        keys
        REQUEST requested_authorizations
        FOR Incident
      RESULT result.

    METHODS get_global_authorizations
      FOR GLOBAL AUTHORIZATION
      IMPORTING
        REQUEST requested_authorizations
        FOR Incident
      RESULT result.

    METHODS ChangeStatus
      FOR MODIFY
      IMPORTING
        keys
        FOR ACTION Incident~ChangeStatus
      RESULT result.

    METHODS SetHistory
      FOR MODIFY
      IMPORTING
        keys
        FOR ACTION Incident~SetHistory.

    METHODS SetDefaultValues
      FOR DETERMINE ON MODIFY
      IMPORTING
        keys
        FOR Incident~SetDefaultValues.

    METHODS SetDefaultHistory
      FOR DETERMINE ON SAVE
      IMPORTING
        keys
        FOR Incident~SetDefaultHistory.

    METHODS ValidateMandatoryFields
      FOR VALIDATE ON SAVE
      IMPORTING
        keys FOR Incident~ValidateMandatoryFields.

    METHODS get_history_index
      IMPORTING
        iv_incuuid TYPE sysuuid_x16
      RETURNING
        VALUE(rv_index) TYPE zdt_inct_h_731-his_id.

ENDCLASS.


CLASS lhc_Incident IMPLEMENTATION.


  "==========================================================
  " VALORES POR DEFECTO AL CREAR INCIDENTE
  "==========================================================
  METHOD SetDefaultValues.

    READ ENTITIES OF ZI_DT_INCT_731 IN LOCAL MODE
      ENTITY Incident
      FIELDS (
        CreationDate
        Status
      )
      WITH CORRESPONDING #( keys )
      RESULT DATA(incidents).

    "Solo registros nuevos
    DELETE incidents WHERE CreationDate IS NOT INITIAL.

    CHECK incidents IS NOT INITIAL.

    "Obtener último Incident ID
    SELECT FROM zdt_inct_731
      FIELDS MAX( incident_id ) AS max_inct_id
      WHERE incident_id IS NOT NULL
      INTO @DATA(lv_max_inct_id).

    IF lv_max_inct_id IS INITIAL.
      lv_max_inct_id = 1.
    ELSE.
      lv_max_inct_id += 1.
    ENDIF.

    "Asignar valores iniciales
    MODIFY ENTITIES OF ZI_DT_INCT_731 IN LOCAL MODE
      ENTITY Incident
      UPDATE
      FIELDS (
        IncidentId
        CreationDate
        Status
      )
      WITH VALUE #(
        FOR incident IN incidents
        (
          %tky         = incident-%tky
          IncidentId   = lv_max_inct_id
          CreationDate = cl_abap_context_info=>get_system_date( )
          Status       = mc_status-open
        )
      ).

  ENDMETHOD.


  "==========================================================
  " HABILITAR / DESHABILITAR CHANGE STATUS
  "==========================================================
  METHOD get_instance_features.

    READ ENTITIES OF ZI_DT_INCT_731 IN LOCAL MODE
      ENTITY Incident
      FIELDS ( Status )
      WITH CORRESPONDING #( keys )
      RESULT DATA(incidents)
      FAILED failed.

    LOOP AT incidents ASSIGNING FIELD-SYMBOL(<incident>).

      DATA(lv_history_index) = get_history_index(
        iv_incuuid = <incident>-IncUuid
      ).

      APPEND VALUE #(
        %tky = <incident>-%tky

        %action-ChangeStatus =
          COND #(
            WHEN <incident>-Status = mc_status-completed
              OR <incident>-Status = mc_status-closed
              OR <incident>-Status = mc_status-canceled
              OR lv_history_index = 0

            THEN if_abap_behv=>fc-o-disabled
            ELSE if_abap_behv=>fc-o-enabled
          )

        %assoc-_History =
          COND #(
            WHEN <incident>-Status = mc_status-completed
              OR <incident>-Status = mc_status-closed
              OR <incident>-Status = mc_status-canceled
              OR lv_history_index = 0

            THEN if_abap_behv=>fc-o-disabled
            ELSE if_abap_behv=>fc-o-enabled
          )
      ) TO result.

    ENDLOOP.

  ENDMETHOD.


  "==========================================================
  " CAMBIAR ESTADO
  "==========================================================
  METHOD ChangeStatus.

    DATA:
      lt_updated_root_entity TYPE TABLE FOR UPDATE ZI_DT_INCT_731,
      lt_association_entity  TYPE TABLE FOR CREATE ZI_DT_INCT_731\_History,
      lv_status              TYPE zdt_inct_731-status,
      lv_text                TYPE zdt_inct_h_731-text,
      lv_max_his_id          TYPE zdt_inct_h_731-his_id,
      lv_his_uuid            TYPE sysuuid_x16,
      lv_error               TYPE abap_bool.

    "Usuario actual
    DATA(lv_current_user) =
      cl_abap_context_info=>get_user_technical_name( ).

    "Para las pruebas del proyecto:
    "tu usuario se considera administrador.
    DATA(lv_is_admin) = xsdbool(
      lv_current_user = 'CB9980001731'
    ).


    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).

      CLEAR:
        lv_status,
        lv_text,
        lv_max_his_id,
        lv_his_uuid.


      "------------------------------------------------------
      " Leer incidente
      "------------------------------------------------------
      READ ENTITIES OF ZI_DT_INCT_731 IN LOCAL MODE
        ENTITY Incident
        ALL FIELDS
        WITH VALUE #(
          ( %tky = <key>-%tky )
        )
        RESULT DATA(incidents)
        FAILED failed.

      READ TABLE incidents
        ASSIGNING FIELD-SYMBOL(<incident>)
        INDEX 1.

      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.


      "Datos del popup
      lv_status = <key>-%param-status.
      lv_text   = <key>-%param-text.


      "------------------------------------------------------
      " VALIDACIÓN: STATUS OBLIGATORIO
      "------------------------------------------------------
      IF lv_status IS INITIAL.

        APPEND VALUE #(
          %tky = <incident>-%tky
        ) TO failed-Incident.

        APPEND VALUE #(
          %tky = <incident>-%tky

          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text     = 'Please select a new status.'
          )

          %op-%action-ChangeStatus = if_abap_behv=>mk-on
          %state_area = 'VALIDATE_STATUS'

        ) TO reported-Incident.

        lv_error = abap_true.
        CONTINUE.

      ENDIF.


      "------------------------------------------------------
      " RESPONSABLE
      "
      "Cuando el incidente está en IP, LocalLastChangedBy
      "representa al usuario responsable.
      "Solo él o el administrador pueden continuar cambiándolo.
      "------------------------------------------------------
      IF <incident>-Status = mc_status-in_progress
         AND <incident>-LocalLastChangedBy IS NOT INITIAL
         AND <incident>-LocalLastChangedBy <> lv_current_user
         AND lv_is_admin = abap_false.

        APPEND VALUE #(
          %tky = <incident>-%tky
        ) TO failed-Incident.

        APPEND VALUE #(
          %tky = <incident>-%tky

          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text =
              'Only the assigned responsible user or an administrator can change this incident.'
          )

          %op-%action-ChangeStatus = if_abap_behv=>mk-on
          %state_area = 'VALIDATE_RESPONSIBLE'

        ) TO reported-Incident.

        lv_error = abap_true.
        CONTINUE.

      ENDIF.


      "------------------------------------------------------
      " PENDING -> COMPLETED NO PERMITIDO
      "------------------------------------------------------
      IF <incident>-Status = mc_status-pending
         AND lv_status = mc_status-completed.

        APPEND VALUE #(
          %tky = <incident>-%tky
        ) TO failed-Incident.

        APPEND VALUE #(
          %tky = <incident>-%tky

          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text =
              'A Pending incident cannot be changed directly to Completed.'
          )

          %op-%action-ChangeStatus = if_abap_behv=>mk-on
          %state_area = 'VALIDATE_STATUS'

        ) TO reported-Incident.

        lv_error = abap_true.
        CONTINUE.

      ENDIF.


      "------------------------------------------------------
      " PENDING -> CLOSED NO PERMITIDO
      "------------------------------------------------------
      IF <incident>-Status = mc_status-pending
         AND lv_status = mc_status-closed.

        APPEND VALUE #(
          %tky = <incident>-%tky
        ) TO failed-Incident.

        APPEND VALUE #(
          %tky = <incident>-%tky

          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text =
              'A Pending incident cannot be changed directly to Closed.'
          )

          %op-%action-ChangeStatus = if_abap_behv=>mk-on
          %state_area = 'VALIDATE_STATUS'

        ) TO reported-Incident.

        lv_error = abap_true.
        CONTINUE.

      ENDIF.


      "------------------------------------------------------
      " ESTADOS FINALES
      " CN / CO / CL ya no pueden cambiar
      "------------------------------------------------------
      IF <incident>-Status = mc_status-completed
         OR <incident>-Status = mc_status-closed
         OR <incident>-Status = mc_status-canceled.

        APPEND VALUE #(
          %tky = <incident>-%tky
        ) TO failed-Incident.

        APPEND VALUE #(
          %tky = <incident>-%tky

          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text =
              'This incident is already in a final status and cannot be changed.'
          )

          %op-%action-ChangeStatus = if_abap_behv=>mk-on
          %state_area = 'VALIDATE_STATUS'

        ) TO reported-Incident.

        lv_error = abap_true.
        CONTINUE.

      ENDIF.


      "------------------------------------------------------
      " Preparar actualización
      "------------------------------------------------------
      APPEND VALUE #(
        %tky        = <incident>-%tky
        Status      = lv_status
        ChangedDate = cl_abap_context_info=>get_system_date( )
      ) TO lt_updated_root_entity.


      "------------------------------------------------------
      " Obtener siguiente History ID
      "------------------------------------------------------
      lv_max_his_id = get_history_index(
        iv_incuuid = <incident>-IncUuid
      ).

      IF lv_max_his_id IS INITIAL.
        lv_max_his_id = 1.
      ELSE.
        lv_max_his_id += 1.
      ENDIF.


      "------------------------------------------------------
      " UUID del historial
      "------------------------------------------------------
      TRY.

          lv_his_uuid =
            cl_system_uuid=>create_uuid_x16_static( ).

        CATCH cx_uuid_error.

          CLEAR lv_his_uuid.

      ENDTRY.


      "------------------------------------------------------
      " Crear History
      "------------------------------------------------------
      IF lv_his_uuid IS NOT INITIAL.

        APPEND VALUE #(
          %tky = <incident>-%tky

          %target = VALUE #(
            (
              %is_draft      = <incident>-%is_draft
              HisUuid        = lv_his_uuid
              IncUuid        = <incident>-IncUuid
              HisId          = lv_max_his_id
              PreviousStatus = <incident>-Status
              NewStatus      = lv_status
              Text           = lv_text
            )
          )

        ) TO lt_association_entity.

      ENDIF.

    ENDLOOP.


    "Si alguna validación falló, no realizar cambios
    CHECK lv_error = abap_false.


    "------------------------------------------------------
    " Actualizar Incident
    "------------------------------------------------------
    IF lt_updated_root_entity IS NOT INITIAL.

      MODIFY ENTITIES OF ZI_DT_INCT_731 IN LOCAL MODE
        ENTITY Incident
        UPDATE
        FIELDS (
          Status
          ChangedDate
        )
        WITH lt_updated_root_entity.

    ENDIF.


    "------------------------------------------------------
    " Insertar History
    "------------------------------------------------------
    IF lt_association_entity IS NOT INITIAL.

      MODIFY ENTITIES OF ZI_DT_INCT_731 IN LOCAL MODE
        ENTITY Incident
        CREATE BY \_History
        FIELDS (
          HisUuid
          IncUuid
          HisId
          PreviousStatus
          NewStatus
          Text
        )
        AUTO FILL CID
        WITH lt_association_entity
        MAPPED mapped
        FAILED failed
        REPORTED reported.

    ENDIF.


    "------------------------------------------------------
    " Refrescar UI
    "------------------------------------------------------
    READ ENTITIES OF ZI_DT_INCT_731 IN LOCAL MODE
      ENTITY Incident
      ALL FIELDS
      WITH VALUE #(
        FOR key IN keys
        ( %tky = key-%tky )
      )
      RESULT DATA(updated_incidents)
      FAILED failed.

    result = VALUE #(
      FOR incident IN updated_incidents
      (
        %tky   = incident-%tky
        %param = incident
      )
    ).

  ENDMETHOD.


  "==========================================================
  " CREAR PRIMER HISTORIAL AL GUARDAR
  "==========================================================
  METHOD SetDefaultHistory.

    MODIFY ENTITIES OF ZI_DT_INCT_731 IN LOCAL MODE
      ENTITY Incident
      EXECUTE SetHistory
      FROM CORRESPONDING #( keys ).

  ENDMETHOD.


  "==========================================================
  " ÚLTIMO ID DEL HISTORIAL
  "==========================================================
  METHOD get_history_index.

    SELECT FROM zdt_inct_h_731
      FIELDS MAX( his_id ) AS max_his_id
      WHERE inc_uuid = @iv_incuuid
        AND his_uuid IS NOT NULL
      INTO @rv_index.

  ENDMETHOD.


  "==========================================================
  " CREAR FIRST INCIDENT
  "==========================================================
  METHOD SetHistory.

    DATA:
      lt_association_entity TYPE TABLE FOR CREATE ZI_DT_INCT_731\_History,
      lv_max_his_id         TYPE zdt_inct_h_731-his_id,
      lv_his_uuid           TYPE sysuuid_x16.

    READ ENTITIES OF ZI_DT_INCT_731 IN LOCAL MODE
      ENTITY Incident
      ALL FIELDS
      WITH CORRESPONDING #( keys )
      RESULT DATA(incidents).

    LOOP AT incidents ASSIGNING FIELD-SYMBOL(<incident>).

      CLEAR:
        lv_max_his_id,
        lv_his_uuid.

      lv_max_his_id = get_history_index(
        iv_incuuid = <incident>-IncUuid
      ).

      IF lv_max_his_id IS INITIAL.
        lv_max_his_id = 1.
      ELSE.
        lv_max_his_id += 1.
      ENDIF.

      TRY.

          lv_his_uuid =
            cl_system_uuid=>create_uuid_x16_static( ).

        CATCH cx_uuid_error.

          CLEAR lv_his_uuid.

      ENDTRY.

      IF lv_his_uuid IS NOT INITIAL.

        APPEND VALUE #(
          %tky = <incident>-%tky

          %target = VALUE #(
            (
              %is_draft = <incident>-%is_draft
              HisUuid   = lv_his_uuid
              IncUuid   = <incident>-IncUuid
              HisId     = lv_max_his_id
              NewStatus = <incident>-Status
              Text      = 'First Incident'
            )
          )

        ) TO lt_association_entity.

      ENDIF.

    ENDLOOP.


    IF lt_association_entity IS NOT INITIAL.

      MODIFY ENTITIES OF ZI_DT_INCT_731 IN LOCAL MODE
        ENTITY Incident
        CREATE BY \_History
        FIELDS (
          HisUuid
          IncUuid
          HisId
          PreviousStatus
          NewStatus
          Text
        )
        AUTO FILL CID
        WITH lt_association_entity.

    ENDIF.

  ENDMETHOD.


  "==========================================================
  " AUTORIZACIONES GLOBALES
  "==========================================================
  METHOD get_global_authorizations.

    IF requested_authorizations-%create = if_abap_behv=>mk-on.
      result-%create = if_abap_behv=>auth-allowed.
    ENDIF.

    IF requested_authorizations-%update = if_abap_behv=>mk-on.
      result-%update = if_abap_behv=>auth-allowed.
    ENDIF.

    IF requested_authorizations-%delete = if_abap_behv=>mk-on.
      result-%delete = if_abap_behv=>auth-allowed.
    ENDIF.

  ENDMETHOD.


  "==========================================================
  " AUTORIZACIONES POR INSTANCIA
  "==========================================================
  METHOD get_instance_authorizations.

    result = VALUE #(
      FOR key IN keys
      (
        %tky    = key-%tky
        %update = if_abap_behv=>auth-allowed
        %delete = if_abap_behv=>auth-allowed
      )
    ).

  ENDMETHOD.


  "==========================================================
  " VALIDACIÓN DE CAMPOS OBLIGATORIOS
  "==========================================================
  METHOD ValidateMandatoryFields.

    READ ENTITIES OF ZI_DT_INCT_731 IN LOCAL MODE
      ENTITY Incident
      FIELDS (
        Title
        Description
        Priority
        Status
        CreationDate
      )
      WITH CORRESPONDING #( keys )
      RESULT DATA(incidents).

    LOOP AT incidents ASSIGNING FIELD-SYMBOL(<incident>).


      "------------------------------------------------------
      " TITLE
      "------------------------------------------------------
      IF <incident>-Title IS INITIAL.

        APPEND VALUE #(
          %tky = <incident>-%tky
        ) TO failed-Incident.

        APPEND VALUE #(
          %tky = <incident>-%tky

          %element-Title = if_abap_behv=>mk-on

          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text     = 'Title is required. Please enter a title.'
          )

          %state_area = 'VALIDATE_MANDATORY'

        ) TO reported-Incident.

      ENDIF.


      "------------------------------------------------------
      " DESCRIPTION
      "------------------------------------------------------
      IF <incident>-Description IS INITIAL.

        APPEND VALUE #(
          %tky = <incident>-%tky
        ) TO failed-Incident.

        APPEND VALUE #(
          %tky = <incident>-%tky

          %element-Description = if_abap_behv=>mk-on

          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text =
              'Description is required. Please enter a description.'
          )

          %state_area = 'VALIDATE_MANDATORY'

        ) TO reported-Incident.

      ENDIF.


      "------------------------------------------------------
      " PRIORITY
      "------------------------------------------------------
      IF <incident>-Priority IS INITIAL.

        APPEND VALUE #(
          %tky = <incident>-%tky
        ) TO failed-Incident.

        APPEND VALUE #(
          %tky = <incident>-%tky

          %element-Priority = if_abap_behv=>mk-on

          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text =
              'Priority is required. Please select a priority.'
          )

          %state_area = 'VALIDATE_MANDATORY'

        ) TO reported-Incident.

      ENDIF.


      "------------------------------------------------------
      " STATUS
      "------------------------------------------------------
      IF <incident>-Status IS INITIAL.

        APPEND VALUE #(
          %tky = <incident>-%tky
        ) TO failed-Incident.

        APPEND VALUE #(
          %tky = <incident>-%tky

          %element-Status = if_abap_behv=>mk-on

          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text     = 'Status is required.'
          )

          %state_area = 'VALIDATE_MANDATORY'

        ) TO reported-Incident.

      ENDIF.


      "------------------------------------------------------
      " CREATION DATE
      "------------------------------------------------------
      IF <incident>-CreationDate IS INITIAL.

        APPEND VALUE #(
          %tky = <incident>-%tky
        ) TO failed-Incident.

        APPEND VALUE #(
          %tky = <incident>-%tky

          %element-CreationDate = if_abap_behv=>mk-on

          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text     = 'Creation Date is required.'
          )

          %state_area = 'VALIDATE_MANDATORY'

        ) TO reported-Incident.

      ENDIF.

    ENDLOOP.

  ENDMETHOD.


ENDCLASS.

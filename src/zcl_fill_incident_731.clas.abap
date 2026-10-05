CLASS zcl_fill_incident_731 DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

ENDCLASS.


CLASS zcl_fill_incident_731 IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.

    "Limpiar catálogos
    DELETE FROM zdt_status_731.
    DELETE FROM zdt_priority_731.


    "Estados
    INSERT zdt_status_731 FROM TABLE @(
      VALUE #(
        ( status_code = 'OP' status_description = 'Open' )
        ( status_code = 'IP' status_description = 'In Progress' )
        ( status_code = 'PE' status_description = 'Pending' )
        ( status_code = 'CO' status_description = 'Completed' )
        ( status_code = 'CL' status_description = 'Closed' )
        ( status_code = 'CN' status_description = 'Canceled' )
      )
    ).

    IF sy-subrc = 0.
      out->write( |{ sy-dbcnt } statuses were added.| ).
    ENDIF.


    "Prioridades
    INSERT zdt_priority_731 FROM TABLE @(
      VALUE #(
        ( priority_code = 'H' priority_description = 'High' )
        ( priority_code = 'M' priority_description = 'Medium' )
        ( priority_code = 'L' priority_description = 'Low' )
      )
    ).

    IF sy-subrc = 0.
      out->write( |{ sy-dbcnt } priorities were added.| ).
    ENDIF.

  ENDMETHOD.

ENDCLASS.

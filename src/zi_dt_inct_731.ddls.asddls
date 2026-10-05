@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Incident Interface View'
@Metadata.ignorePropagatedAnnotations: true

define root view entity ZI_DT_INCT_731
  as select from zdt_inct_731

  composition [0..*] of ZI_DT_INCT_H_731 as _History

  association [0..1] to zdt_status_731 as _Status
    on $projection.Status = _Status.status_code

  association [0..1] to zdt_priority_731 as _Priority
    on $projection.Priority = _Priority.priority_code

{
  key inc_uuid              as IncUuid,
      incident_id           as IncidentId,
      title                 as Title,
      description           as Description,
      status                as Status,
      priority              as Priority,
      creation_date         as CreationDate,
      changed_date          as ChangedDate,
      local_created_by      as LocalCreatedBy,
      local_created_at      as LocalCreatedAt,
      local_last_changed_by as LocalLastChangedBy,
      local_last_changed_at as LocalLastChangedAt,
      last_changed_at       as LastChangedAt,

      _History,
      _Status,
      _Priority
}

@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Incident History Interface View'
@Metadata.ignorePropagatedAnnotations: true

define view entity ZI_DT_INCT_H_731
  as select from zdt_inct_h_731

  association to parent ZI_DT_INCT_731 as _Incident
    on $projection.IncUuid = _Incident.IncUuid

{
  key his_uuid              as HisUuid,
      inc_uuid              as IncUuid,
      his_id                as HisId,
      previous_status       as PreviousStatus,
      new_status            as NewStatus,
      text                  as Text,
      local_created_by      as LocalCreatedBy,
      local_created_at      as LocalCreatedAt,
      local_last_changed_by as LocalLastChangedBy,
      local_last_changed_at as LocalLastChangedAt,
      last_changed_at       as LastChangedAt,

      _Incident
}

@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Incident History Consumption View'
@Metadata.allowExtensions: true

define view entity ZC_DT_INCT_H_731
  as projection on ZI_DT_INCT_H_731
{
  key HisUuid,
      IncUuid,
      HisId,
      PreviousStatus,
      NewStatus,
      Text,
      LocalCreatedBy,
      LocalCreatedAt,
      LocalLastChangedBy,
      LocalLastChangedAt,
      LastChangedAt,

      _Incident : redirected to parent ZC_DT_INCT_731
}

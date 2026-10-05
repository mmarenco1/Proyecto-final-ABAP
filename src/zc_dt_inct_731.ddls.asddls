@Metadata.allowExtensions: true
@EndUserText.label: 'Incident Consumption View'
@AccessControl.authorizationCheck: #CHECK

define root view entity ZC_DT_INCT_731
  provider contract transactional_query
  as projection on ZI_DT_INCT_731
{
  key IncUuid,
      IncidentId,
      Title,
      Description,
      Status,
      Priority,
      CreationDate,
      ChangedDate,
      LocalCreatedBy,
      LocalCreatedAt,
      LocalLastChangedBy,
      LocalLastChangedAt,
      LastChangedAt,

      _History : redirected to composition child ZC_DT_INCT_H_731
}

@EndUserText.label: 'Parameters for Change Status'

define abstract entity ZDD_CHANGE_STATUS_PARAM_731
{
  @EndUserText.label: 'Change Status'
  @Consumption.valueHelpDefinition: [
    {
      entity.name: 'ZDD_STATUS_VH_731',
      entity.element: 'StatusCode',
      useForValidation: true
    }
  ]
  status : abap.char(2);

  @EndUserText.label: 'Add Observation Text'
  text : abap.char(80);
}

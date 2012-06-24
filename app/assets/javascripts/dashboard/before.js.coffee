@Model      = {}
@Controller = {}
@Manager    = {}

jQuery.validator.messages = 
  required:    "required"
  remote:      "remote"
  email:       "email"
  url:         "url"
  date:        "date"
  dateISO:     "dateISO"
  number:      "number"
  digits:      "digits"
  creditcard:  "creditcard"
  equalTo:     "equalto"
  maxlength:   "maxlength"
  minlength:   "minlength"
  rangelength: "rangelength"
  range:       "range"
  max:         "max"
  min:         "min"

jQuery.validator.setDefaults
  invalidHandler: (event, validator)->
    $("[id^='invalid-']", event.currentTarget).addClass "hidden"
    for obj in validator.errorList
      context = $(obj.element).parents(".control-group")[0]
      if context
        console.log "#invalid-#{obj.element.name}-with-#{obj.message}"
        $("#invalid-#{obj.element.name}-with-#{obj.message}").removeClass "hidden"
      $(context).addClass "error"
  showErrors: -> null

jQuery.validator.addMethod "regex", (value, element, params)->
  console.log this
  false
, "regex"
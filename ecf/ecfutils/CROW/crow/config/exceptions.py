from crow.exceptions import CROWException

# Exceptions generic to the CROW API:
class ConfigError(CROWException): pass
class ConfigUserError(ConfigError): pass

# Exceptions specific to this implementation of the config subsystem:

class ConfigConditionalError(ConfigError): pass
class ConditionalMissingDoWhen(ConfigConditionalError): pass
class ConditionalOverspecified(ConfigConditionalError): pass
class ConditionalInvalidOtherwise(ConfigConditionalError): pass
class ConditionalMissingOtherwise(ConfigConditionalError): pass

class ConfigCalcError(ConfigError): pass
class CalcRecursionTooDeep(ConfigCalcError): pass
class ExpandMissingResult(ConfigCalcError): pass
class CalcKeyError(ConfigCalcError): pass

class TemplateError(ConfigError): pass
class VariableMissing(TemplateError): pass
class InvalidConfigTemplate(TemplateError): pass
class InvalidConfigValue(TemplateError): pass
class InvalidConfigType(TemplateError): pass
class ValidationRecursionError(TemplateError): pass

class TemplateErrors(ConfigError):
    def __init__(self,errors):
        super().__init__(self,'\n'.join([ str(e) for e in errors ]))
        self.template_errors=list(errors)
    def __str__(self):
        return 'Scope did not validate:\n' + \
            '\n'.join(self.template_errors)

class DependError(ConfigError): pass

from crow.sysenv.exceptions import UnknownSchedulerError
from crow.sysenv.schedulers.MoabTorque import Scheduler as MoabTorqueScheduler
from crow.sysenv.schedulers.MoabAlps import Scheduler as MoabAlpsScheduler
from crow.sysenv.schedulers.LSFAlps import Scheduler as LSFAlpsScheduler

KNOWN_SCHEDULERS={
    'MoabTorque': MoabTorqueScheduler,
    'MoabAlps': MoabAlpsScheduler,
    'LSFAlps': LSFAlpsScheduler
    }

def get_scheduler(name,settings):
    if name not in KNOWN_SCHEDULERS:
        raise UnknownSchedulerError(name)
    cls=KNOWN_SCHEDULERS[name]
    return cls(settings)

def has_scheduler(name):
    return name in KNOWN_SCHEDULERS

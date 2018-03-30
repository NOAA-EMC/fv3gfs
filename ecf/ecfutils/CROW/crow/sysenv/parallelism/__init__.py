from crow.sysenv.exceptions import UnknownParallelismError
import crow.sysenv.parallelism.HydraIMPI
import crow.sysenv.parallelism.AprunCrayMPI
from crow.sysenv.parallelism.HydraIMPI \
    import Parallelism as HydraIMPIParallelism
from crow.sysenv.parallelism.AprunCrayMPI \
    import Parallelism as AprunCrayMPIParallelism

KNOWN_PARALLELISM={
    'HydraIMPI': HydraIMPIParallelism,
    'AprunCrayMPI': AprunCrayMPIParallelism
    }


def get_parallelism(name,settings):
    if name not in KNOWN_PARALLELISM:
        raise UnknownParallelismError(name)
    cls=KNOWN_PARALLELISM[name]
    return cls(settings)

def has_parallelism(name):
    return name in KNOWN_PARALLELISM

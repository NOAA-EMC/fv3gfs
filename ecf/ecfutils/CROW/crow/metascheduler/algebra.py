"""In-place simplification of dependency trees by applying rules of
boolean algebra.  Ensures short circuit assumptions still hold."""

import crow.config
from crow.config import OrDependency,AndDependency,NotDependency, \
    TRUE_DEPENDENCY, FALSE_DEPENDENCY, LogicalDependency,\
    CycleExistsDependency,TaskExistsDependency, StateDependency, \
    EventDependency, RUNNING, COMPLETED, FAILED, TaskExistsDependency
from crow.tools import typecheck, NamedConstant

__all__=[ 'complexity', 'simplify', 'assume' ]

def assume(tree,existing_cycles,current_cycle,assume_complete=None,
           assume_never_run=None):
    typecheck('tree',tree,LogicalDependency)
    if isinstance(tree,CycleExistsDependency):
        rel_cycle=tree.dt+current_cycle
        if rel_cycle in existing_cycles:
            return TRUE_DEPENDENCY
        return FALSE_DEPENDENCY
    elif isinstance(tree,TaskExistsDependency):
        cycle=current_cycle+tree.view.path[0]
        if assume_complete and assume_complete(tree.path) or \
           assume_never_run and assume_never_run(tree.path):
            return FALSE_DEPENDENCY
        alarm=tree.view.get_alarm(default=existing_cycles)
        if cycle in alarm:
            return TRUE_DEPENDENCY
        else:
            return FALSE_DEPENDENCY
    elif isinstance(tree,AndDependency):
        a=TRUE_DEPENDENCY
        for d in tree:
            a=a & assume(d,existing_cycles,current_cycle,assume_complete,
                         assume_never_run)
        return a
    elif isinstance(tree,OrDependency):
        a=FALSE_DEPENDENCY
        for d in tree:
            a=a | assume(d,existing_cycles,current_cycle,assume_complete,
                         assume_never_run)
        return a
    elif isinstance(tree,NotDependency):
        return ~assume(tree.depend,existing_cycles,current_cycle,
                       assume_complete,assume_never_run)
    elif isinstance(tree,StateDependency):
        if assume_never_run and assume_never_run(tree.path):
            return FALSE_DEPENDENCY
        if assume_complete and assume_complete(tree.path):
            return TRUE_DEPENDENCY if tree.state==COMPLETED \
              else FALSE_DEPENDENCY
        if current_cycle+tree.path[0] not in existing_cycles:
            # Prior cycle tasks will never complete, run, or fail.
            return FALSE_DEPENDENCY
        return tree
    elif isinstance(tree,EventDependency):
        if assume_never_run and assume_never_run(tree.event.parent.path):
            return FALSE_DEPENDENCY
        if assume_complete and assume_complete(tree.event.parent.path):
            return FALSE_DEPENDENCY
        if current_cycle+tree.path[0] not in existing_cycles:
            # Prior cycle events will never be set.
            return FALSE_DEPENDENCY
        return tree

    return tree

def complexity(tree):
    if isinstance(tree,AndDependency) or isinstance(tree,OrDependency):
        return 1.2*sum([ complexity(dep) for dep in tree.depends ])
    elif isinstance(tree,NotDependency):
        return 1.2*complexity(tree.depend)
    return 1

def simplify(tree):
    typecheck('tree',tree,LogicalDependency)
    tree=tree.copy_dependencies()
    tree=simplify_no_de_morgan(tree)
    return de_morgan(tree)

def simplify_no_de_morgan(tree):
    # Apply all simplificatios except de morgan's law.  Called from
    # within de_morgan() to apply all other simplifications to the
    # result of de-morganing the tree.
    if isinstance(tree,OrDependency) or isinstance(tree,AndDependency):
        tree=simplify_sequence(tree)
    if isinstance(tree,NotDependency):
        tree.depend=simplify(tree.depend)
        if isinstance(tree.depend,NotDependency):
            return tree.depend.depend # not not x = x
        elif tree.depend==TRUE_DEPENDENCY:
            return FALSE_DEPENDENCY  # NOT true = false
        elif tree.depend==FALSE_DEPENDENCY:
            return TRUE_DEPENDENCY  # NOT false = true
    return tree

def de_morgan(tree):
    # Apply de morgan's law, choose least complex option.
    if not isinstance(tree,NotDependency): return tree
    dup=tree.copy_dependencies()
    if isinstance(dup.depend,AndDependency):
        # not ( x and y ) = (not x) or (not y)
        alternative=simplify_no_de_morgan(OrDependency(
            *[ NotDependency(dep) for dep in dup.depend.depends ]))
    elif isinstance(dup.depend,OrDependency):
        # not ( x or y ) = (not x) and (not y)
        alternative=simplify_no_de_morgan(AndDependency(
            *[ NotDependency(dep) for dep in dup.depend.depends ]))
    else: return tree
    if complexity(alternative)<complexity(tree):
        return alternative
    return tree

def and_merge_ors(ors):
    # (X + B1 + B2 + Y) + (X + C1 + C2 + Y) = X + (B1+B2)(C1+C2) + Y
    original=AndDependency(*ors)
    ors=original.copy_dependencies().depends
    assert(isinstance(ors,list))
    min_len=min([ len(orr) for orr in ors ])
    i=0
    while i<min_len and all( [ ors[j].depends[i]==ors[0].depends[i] for j in range(len(ors)) ] ):
        i=i+1

    common_before=ors[0].depends[0:i]
    for j in range(len(ors)):
        ors[j].depends=ors[j].depends[i:]

    i=-1
    min_len=min([ len(orr) for orr in ors ])
    neg_limit=-min_len-1
    while i>neg_limit and all( [ ors[j].depends[i]==ors[0].depends[-1] for j in range(len(ors)) ] ):
        i=i-1

    common_after=ors[0].depends[i+1:]
    if i<-1:
        for j in range(len(ors)):
            new=ors[j].depends[:i+1]
            ors[j].depends=new

    if len(common_before)>1:
        dep=OrDependency(*common_before)
    elif len(common_before)==1:
        dep=common_before[0]
    else:
        dep=FALSE_DEPENDENCY

    middle_dep=TRUE_DEPENDENCY
    have_middle_dep=False
    for orr in ors:
        have_middle_dep=have_middle_dep or len(orr)
        if len(orr)>1:
            middle_dep=middle_dep&orr
        elif len(orr):
            middle_dep=middle_dep&orr.depends[0]
    if have_middle_dep: dep = dep | middle_dep

    if len(common_after)>1:
        dep=dep | OrDependency(*common_after)
    elif len(common_after)==1:
        dep=dep | common_after[0]

    if complexity(dep)<complexity(original):
        return dep
    return None

def simplify_sequence(dep,no_merge=False):
    deplist=dep.depends
    cls=type(dep)
    is_or = isinstance(dep,OrDependency)

    # Simplify and merge subexpressions.
    expanded=True
    while expanded:
        expanded=False

        # simplify each subexpression
        for i in range(len(deplist)):
            deplist[i]=simplify(deplist[i])

        i=0
        while i<len(deplist):
            if type(deplist[i]) == type(dep):
                # A & (B & C) = A & B & C
                # A | (B | C) = A | B | C
                deplist=deplist[0:i]+deplist[i].depends+deplist[i+1:]
                expanded=True
            elif isinstance(dep,AndDependency) \
                 and isinstance(deplist[i],OrDependency):
                j=i
                while j<len(deplist) and isinstance(deplist[j],OrDependency):
                    j=j+1
                if j>i+1:
                    result=and_merge_ors(deplist[i:j])
                    if result is not None:
                        deplist[i]=result
                        del deplist[i+1:j]
                        expanded=True
                i=i+1
            else:
                i=i+1

    i=0
    while i<len(deplist):
        assert(deplist)
        if len(deplist)==1:
            return deplist[0]
        elif deplist[i]==TRUE_DEPENDENCY:
            if is_or: return deplist[i] # A|true = true
            del deplist[i] # A&true = A
        elif deplist[i]==FALSE_DEPENDENCY:
            if not is_or: return deplist[i] # A&false = false
            del deplist[i] # A|false = A
        else:
            j=i+1
            seen_other=False
            del_i=False
            while j<len(deplist):
                if deplist[i]==deplist[j]:
                    del deplist[j]
                    continue
                elif ( isinstance(deplist[j],NotDependency) \
                       and deplist[j].depend==deplist[i] ) or \
                     ( isinstance(deplist[i],NotDependency) \
                       and deplist[i].depend==deplist[j] ):
                    if is_or and not seen_other:
                        del_i=True
                        del deplist[j]
                        if len(deplist)==1:
                            return TRUE_DEPENDENCY
                        continue
                    elif not is_or:
                        return FALSE_DEPENDENCY
                seen_other=True
                j=j+1
            if len(deplist)==1:
                return deplist[0]
            if del_i:
                del deplist[i]
            else:
                i=i+1

    return cls(*deplist)

def test():
    from datetime import timedelta
    DEP1=crow.config.CycleExistsDependency(timedelta())
    DEP2=crow.config.CycleExistsDependency(timedelta(seconds=3600))
    DEP3=crow.config.CycleExistsDependency(timedelta(seconds=7200))
    DEP4=crow.config.CycleExistsDependency(timedelta(seconds=10800))

    assert(abs(complexity(DEP1|DEP2)-2.4)<1e-3)
    assert(abs(complexity(DEP1&DEP2)-2.4)<1e-3)
    assert(abs(complexity(~(DEP1&DEP2))-2.88)<1e-3)

    assert(simplify(~DEP1 | DEP1)==TRUE_DEPENDENCY)
    assert(simplify(~DEP1 & DEP1)==FALSE_DEPENDENCY)
    assert(simplify(~(~DEP1 | ~DEP2)) == DEP1&DEP2)
    assert(simplify(~DEP2 & ~(~DEP1 | ~DEP2)) == FALSE_DEPENDENCY)

    assert(simplify( (DEP1 | DEP2 | DEP4) & (DEP1 | DEP3 | DEP4) ) == \
           DEP1 | DEP2&DEP3 | DEP4)

import logging
from collections.abc import Sequence
from datetime import datetime, timedelta

import crow.config
from crow.config import Suite, Task
from crow.config import OutputSlot as ConfigOutputSlot
from crow.config import InputSlot as ConfigInputSlot
from crow.dataflow.interface import Dataflow
from crow.tools import typecheck

_logger=logging.getLogger('crow.dataflow')

SPECIAL_VARS=set(['Loc', 'task_path_var', 'task_path_str', 'task_path_list','up'])

def _parse_slot(actor,slot,sdata,flow):
    meta=dict(sdata)
    if flow == 'O':
        if not 'Loc' in meta:
            raise ValueError(f'{actor} {slot}: Must have a Loc entry')
        loc=meta['Loc']

    #typecheck(f'{actor} {slot}: Loc',loc,str)
    metakeep=dict()
    for key in meta:
        if key in SPECIAL_VARS: continue
        val=meta[key]
        if isinstance(val,str) or isinstance(val,int) or isinstance(val,float):
            metakeep[key]=val
        elif isinstance(val,datetime) or isinstance(val,timedelta):
            metakeep[key]=val
        elif isinstance(val,Sequence) and val:
            val0=val[0]
            if isinstance(val0,str) or isinstance(val0,int) \
               or isinstance(val0,float) or isinstance(val0,datetime) \
               or isinstance(val0,timdelta):
                metakeep[key]=[ v for v in val ]
    _logger.debug(f"{actor}.{slot}: metadata subsetted from {meta} is {metakeep}")
    if flow=='O':
        _logger.debug(f"{actor}.{slot}: metadata is {metakeep} location {loc}")
        return loc, metakeep
    else:
        return metakeep

def _parse_input_slot(actor,slot,sdata):
    meta=dict(sdata)
    if not 'Out' in meta:
        raise ValueError(f'{actor} {slot}: Must have an Out entry')
    out=meta['Out']
    if not out.is_output_slot():
        raise TypeError(f'{actor} {slot}: Out must be a '
                        '!Message for an !OutputSlot')
    del meta['Out']
    return out, meta
    
def _walk_task_tree_for(suite,cls):
    for item in suite.walk_task_tree():
        if isinstance(item.viewed,cls):
            yield item.get_actor_path(),item.get_slot_name(),item

def meta_expand_iter(meta):
    for k,v in meta.items():
        if isinstance(v,list):
            for item in v:
                newmeta=dict(meta)
                newmeta[k]=item
                for m in meta_expand_iter(newmeta):
                    yield m
            return
    yield meta
                

def from_suite(suite,filename):
    typecheck('suite',suite,Suite)
    typecheck('filename',filename,str)
    df=Dataflow(filename)

    # First pass: add output slots:
    for actor, slot, sdata in _walk_task_tree_for(suite,ConfigOutputSlot):
        loc, meta = _parse_slot(actor,slot,sdata,'O')
        df.add_output_slot(actor,slot,loc,meta)

    # Second pass: add input slots:
    for actor, slot, sdata in _walk_task_tree_for(suite,ConfigInputSlot):
        meta = _parse_slot(actor,slot,sdata,'I')
        _logger.debug(f'{actor}.{slot}: add input slot with meta {meta}')
        df.add_input_slot(actor,slot,meta)

        for ometa in meta_expand_iter(meta):
            _logger.debug(f'{actor}.{slot}: will check meta {ometa}')

        for ometa in meta_expand_iter(meta):
            _logger.debug(f"{actor}.{slot}: check input slot meta {ometa}")
            odata=sdata.get_output_slot(ometa)

            oslot=None
            for oslot in df.find_output_slot(
                    odata.get_actor_path(),odata.get_slot_name(),ometa):
                break

            islot=None
            for islot in df.find_input_slot(actor,slot,ometa):
                break
            assert(islot)
            if not oslot: raise ValueError(f'{actor}.{slot} output refers to '
                                           'invalid or missing output slot.')
            _logger.debug(f"{islot}: connect to {oslot}")
            islot.connect_to(oslot)
    return df


                

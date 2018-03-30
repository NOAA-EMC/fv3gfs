#! /usr/bin/env python3.6

import sys
import crow.config

toyml=crow.config.from_file('original.yaml')
toyml_back=crow.config.to_yaml(toyml)
print('converted back: \n'+toyml_back)
toyml_back_toyml=crow.config.from_string(toyml_back)
toyml_back_toyml_back=crow.config.to_yaml(toyml_back_toyml)

print('Check for correct conversion by comparing YAML to YAML')
assert(toyml_back == toyml_back_toyml_back)

print('Check again by comparing the objects read from YAML')
assert(toyml == toyml_back_toyml)

print('Success')

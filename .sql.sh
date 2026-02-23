#!/bin/bash

export SQL0="core_count >= 12 AND memnode >= 32768 AND wattmeter=YES AND NOT cluster IN ('parasilo') AND (cluster!='paradoxe' OR host LIKE 'paradoxe-_.%' OR host LIKE 'paradoxe-1_.%' OR host LIKE 'paradoxe-2_.%' OR host LIKE 'paradoxe-30.%' OR host LIKE 'paradoxe-31.%' OR host LIKE 'paradoxe-32.%')"
export SQL1="core_count >= 4 AND memnode >= 8192"

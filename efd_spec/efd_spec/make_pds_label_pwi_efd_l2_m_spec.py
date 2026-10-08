import os
import sys
import hashlib
import pathlib
import datetime
import time
import platform
import cdflib
from jinja2 import Template, Environment, FileSystemLoader

args = sys.argv

# Directory of CDF files and selected file name from command line input
dir_cdf = args[1]
l2_cdf_file_name = args[2]
print(dir_cdf, l2_cdf_file_name)

# Directories of template and label files and template file name from command line input
dir_template = args[3]
template_file_name = args[4]
dir_label = args[5]
print(dir_template, template_file_name, dir_label,)

# Read template file with jinja2
env = Environment(loader=FileSystemLoader(dir_template))
template = env.get_template(template_file_name)

# Read L2 CDF file
if not os.path.isfile(dir_cdf + '/' + l2_cdf_file_name):
    print(' CDF file not found')
    exit()

cdf_file = cdflib.CDF(dir_cdf + '/' + l2_cdf_file_name)
g_att = cdf_file.globalattsget()
variables = cdf_file.cdf_info().zVariables
info = cdftool.cdfinfo(dir_cdf + '/' + l2_cdf_file_name)
file_info = get_file_info(dir_cdf + '/' + l2_cdf_file_name)

# Get the string time data
strtime_var = cdf_file.varget('strtime')

# Get the offest value for each variables
offset_value = []
record_number = []

for variable in variables:   
    offset_value.append(info.var_info[variable]['offset_for_var'])
    record_number.append(info.var_info[variable]['max_rec'])

print(offset_value)

# Get the information (creation time, file size, and md5chksum) of L2 CDF file
l2_cdf_creation_time = file_info['creation_time']
l2_cdf_size = file_info['size']
l2_cdf_md5 = file_info['md5']

# Input Data
# Creation time of PDS4 label file
create_date = datetime.date.today() 

# Publication year of PDS4 label file
publication_year =  l2_cdf_creation_time[0:4]

# Date of CDF file
yyyymmdd = l2_cdf_file_name[-23:-15]   
yyyy = yyyymmdd[0:4]

# Definition of the dictionary used as the input data
context = {
    "YYYYMMDD": yyyymmdd,
    "publication_year": publication_year,
    "create_date": create_date,
    "title": g_att['TITLE'][0],
    "PI_name": g_att['PI_name'][0],
    "Data_start_time": strtime_var[0],
    "Data_end_time": strtime_var[len(strtime_var)-1],    
    "PDS_logical_identifier": g_att['PDS_LOGICAL_IDENTIFIER'][0],
    "PDS_version_identifier": g_att['PDS_VERSION_IDENTIFIER'][0],  
    "PDS_sclk_start_count": g_att['PDS_SCLK_START_COUNT'][0],
    "PDS_sclk_stop_count": g_att['PDS_SCLK_STOP_COUNT'][0],  
    "processing_software_title": g_att['GENERATION_SOFTWARE'][0],
    "processing_software_version": g_att['SOFTWARE_VERSION'][0],  
    "l1_cdf_file_name": g_att['SOURCE_FILE'][0],
    "l2_cdf_file_name": l2_cdf_file_name, 
    "l2_cdf_create_time": l2_cdf_creation_time, 
    "l2_cdf_size": l2_cdf_size, 
    "l2_cdf_md5": l2_cdf_md5,
    "l2_cdf_time_elements": record_number[0],
    "l2_cdf_epoch_offset": offset_value[0],
    "l2_cdf_strtime_offset": offset_value[1],
    "l2_cdf_mdp_ti_offset": offset_value[2],
    "l2_cdf_time_width_offset": offset_value[3],
    "l2_cdf_spec_freq_offset": offset_value[4],
    "l2_cdf_spec_width_offset": offset_value[5],
    "l2_cdf_Eu_power_offset": offset_value[6],
    "l2_cdf_Ev_power_offset": offset_value[7],
    "l2_cdf_spinperiod_offset": offset_value[8],
    "l2_cdf_quality_flag_offset": offset_value[9],
    "l2_cdf_quality_level_offset": offset_value[10],
    "l2_cdf_BIAS_LVL_U1_offset": offset_value[11],
    "l2_cdf_BIAS_LVL_U2_offset": offset_value[12],
    "l2_cdf_BIAS_LVL_V1_offset": offset_value[13],
    "l2_cdf_BIAS_LVL_V2_offset": offset_value[14],
}


#print(str(context))

#Output rendered file
rendered_file = template.render(context)
#print(str(rendered_file))

if not os.path.isdir(dir_label + '/' + yyyy + '0101_' + yyyy + '1231/'):
    os.makedirs(dir_label + '/' + yyyy + '0101_' + yyyy + '1231/')
    print(dir_label + '/' + yyyy + '0101_' + yyyy + '1231/')

# 'bc_mmo_pwi-efd_l2_l-spec_'+yyyymmdd+'.lblx' --> l2_cdf_file_name[:-4]
# because name convention rules were changed

with open(dir_label + '/' + yyyy + '0101_' + yyyy + '1231/' + l2_cdf_file_name[:-4] + '.lblx', 'w', encoding = 'utf-8') as f:
    f.write(rendered_file)

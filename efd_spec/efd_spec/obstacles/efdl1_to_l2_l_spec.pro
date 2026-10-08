;+
; PRO efdl1_to_l2_l_spec
;
; :Description:
;    Read EFD L1 CDF data and json file and put L1 data value into L2 data.
;
; :Params:
;
; :Keywords:
; outdatadir: Directory in which the CDF data file is saved
; cdfdeffpath: File path of the master CDF table in csv 
;
; :Examples:
; IDL> makecdf_mmo_pwi_efd_l2_l_spec, 20181110, cdfi
; 
; :History:
; 2024/03/18: Just drafted. 
; 
;
; :Author:
; Atsuki Shinbori, ISEE (shinbori at isee.nagoya-u.ac.jp)
;
;-

pro efdl1_to_l2_l_spec, date, cdfi, gitinfo = gitinfo, $
                          versionstr=versionstr, l1dat=l1dat, debug = debug

  if ~keyword_set(debug) then debug = 0 ;; For debugging
  
  if n_params() ne 2 then return

  if ~is_struct(cdfi) then begin
    dprint, 'the given cdfi structure is not a structure!'
    return
  endif

  mmocdf_init

  ;---Load Lv1 etall data and others
  ;---e.g., data/chs/satellite/mmo/l1sample/pwi/efd/l1/Spec/2018/11/bc_mmo_pwi-efd_l1_l-spec_20181110_r01-v00-00.cdf
  if typename(l1dat) ne 'ORDEREDHASH' then begin
   ;---File path of a Lv.1 data 
    l1rootdir = '/home/miosc/mio-sc/work_local/data_org/bc/mmo/'  ;;!mmocdf.dat_org_dir
    ts = time_struct( string(date) )
    syyyy = string(ts.year, '(I04)') + '/' ;; 2018/
    syyyymm = string(ts.year, '(I04)') + '/' + string(ts.month, '(I02)') + '/' ;; 2018/03/
    symd = strtrim( string(date), 2 )
    l1fpath = l1rootdir + 'pwi/efd/l1/' + syyyy + 'bc_mmo_pwi-efd_l1_l-spec_'+symd+'_r01-v00-00.cdf'

   ;---Read Lv.1 data and store them in a hash
    if ~file_test( l1fpath ) then begin
      dprint, 'Cannot find a Lv.1 data file!  --> ' + l1fpath
      return
    endif
    
   ;---CDF ver. 3.8.1 or newer is needed to use cdf_readcdf().
    l1dat = cdf_readcdf(l1fpath)
    if typename(l1dat) ne 'ORDEREDHASH' then begin
      dprint, 'Lv.1 data was not normally stored in an ordered hash!'
      dprint, 'Failed to create a Lv.2 pre CDF file!'
      return
    endif
  endif

  
 ;---Extract the file name of the source Lv.1 data
  l1fname = file_basename( l1dat['CDFInfo','FileName'] )
  src_file_list = [ l1fname ]
 

 ;---Get the source code name and rev. number
  get_script_info_git, gitinfo = gitinfo



 ;========Populate g-attributes in a data structure for Lv.2 pre data============
  
  if debug then dprint, 'Putting g-attrs'
  
 ;---Name of CDF file
  cdfnm_tmpl = cdfi.filename  ;; bc_mmo_pwi-efd_l2_l-spec_YYYYMMDD_rXX-vXX-XX.cdf
  if debug then dprint, 'before :'+cdfnm_tmpl

 ;---Divide a file name template into prefix + the ymd+ver part
  prefix = strmid( cdfnm_tmpl, 0, strpos( cdfnm_tmpl, '_YYYYMMDD' )+1 ) ;; bc_mmo_pwi-efd_l2_l-spec_
  ymdver = strmid( cdfnm_tmpl, strpos( cdfnm_tmpl, '_YYYYMMDD' )+1 ) ;; YYYYMMDD_rXX_vXX_XX.cdf

 ;---Combine the prefix and the ymd+ver part whose date string has been replaced with the designated date
  cdfnm_tmpl = prefix + time_string( string(date), tfor=ymdver ) ;; Overwrite YYYYMMDD

 ;---Determing the version number and overwrite rXX_vXX_XX
  if ~undefined(versionstr) then begin
    sverno = versionstr
  endif else sverno = cdfi.g_attributes.data_version ;; r00_v00_00

  cdffn = str_sub( cdfnm_tmpl, 'rXX-vXX-XX', sverno )
 
 ;---Element in the cdfi structure is overwritten.
  cdfi.filename = cdffn  
  if debug then dprint, 'CDF fname finalized: '+ cdffn

 ;---Element in the PDS_logical_identifier is overwritten.
  l1gatts = l1dat['GlobalAttrs']
  keys = ['START_TI', 'END_TI', 'DATA_START_TIME', 'DATA_END_TIME', 'PDS_LOGICAL_IDENTIFIER']
  prefix = 'urn:jaxa:darts:bc_mmo_pwi:data_calibrated:bc-mmo-pwi_efd_l2_l-spec_'
  ymdver = strtrim(string(date),2) ;; YYYYMMDD
  cdfi.g_attributes.PDS_logical_identifier = prefix + ymdver

 ;---Start and end time of data
  strtime = strmid(CDF_ENCODE_TT2000( l1dat['Variables', 'epoch', 'VarData'] ), 0, 26)
  
  if l1gatts.haskey('START_TI') then begin
     cdfi.g_attributes.start_ti = ( l1gatts['START_TI'] )[0]
  end else begin
     cdfi.g_attributes.start_ti = (l1dat['Variables', 'mdp_ti', 'VarData'])[0]
  endelse

  if l1gatts.haskey('END_TI') then begin
     cdfi.g_attributes.end_ti = ( l1gatts['END_TI'] )[0]
  endif else begin
     cdfi.g_attributes.end_ti = (l1dat['Variables', 'mdp_ti', 'VarData'])[n_elements((l1dat['Variables', 'mdp_ti', 'VarData']))-1]
  endelse

  if l1gatts.haskey('DATA_START_TIME') then begin
     cdfi.g_attributes.data_start_time = ( l1gatts['DATA_START_TIME'] )[0]
  end else begin
     cdfi.g_attributes.data_start_time = strmid(strtime[0],0,4) + strmid(strtime[0],5,2) + strmid(strtime[0],8,2) $
                                         +' '+ strmid(strtime[0],11,2)+strmid(strtime[0],14,2)+strmid(strtime[0],17,2)
  endelse  
  if l1gatts.haskey('DATA_END_TIME') then begin
     cdfi.g_attributes.data_end_time = ( l1gatts['DATA_END_TIME'] )[0]
  end else begin
     cdfi.g_attributes.data_end_time = strmid(strtime[n_elements(strtime)-1],0,4) + strmid(strtime[n_elements(strtime)-1],5,2) + strmid(strtime[n_elements(strtime)-1],8,2) $
                                        + ' ' + strmid(strtime[n_elements(strtime)-1],11,2)+strmid(strtime[n_elements(strtime)-1],14,2)+strmid(strtime[n_elements(strtime)-1],17,2)
  endelse  
  
 ;---Source files and ancillary files
  src_files = strjoin( file_basename(src_file_list), ' ' )
  cdfi.g_attributes.source_file = src_files
 
 ;---Ancillary file is empty (actually 1 blank space) currently
  anc_files = ' '  
  cdfi.g_attributes.ancillary_file = anc_files

 ;---Data version
  cdfi.g_attributes.data_version = sverno

 ;---the Rules of use is unchanged from the on in the data def. table

  
 ;=======Put PWI-EFD L1 data arrays in a data structure for Lv.2 data=======

 ;---Variable list:
 ;---epoch strtime time_width mdp_ti 
  
 ;---Put Lv1 data values in the cdfi structure
  if debug then dprint, 'Now putting PWI-EFD L1 data in L2p dat structure ...'
  nepoch = n_elements( l1dat['Variables','epoch','VarData'] )
  nepoch_tmp = nepoch 

  varnames = cdfi.vars.name
  
 ;---epoch: long64 [times]
  readcdf_var_to_cdfi_var, cdfi, 'epoch', l1dat['Variables', 'epoch', 'VarData'], nepoch

 ;---epoch_delta1: float [times]
  readcdf_var_to_cdfi_var, cdfi, 'epoch_delta1', l1dat['Variables', 'epoch_delta1', 'VarData'], nepoch

 ;---epoch_delta2: float [times]
  readcdf_var_to_cdfi_var, cdfi, 'epoch_delta2', l1dat['Variables', 'epoch_delta2', 'VarData'], nepoch

 ;---str_time: string [times]
  strtime = strmid(CDF_ENCODE_TT2000( l1dat['Variables', 'epoch', 'VarData'] ), 0, 26) + 'Z' ; epoch time to unix time (string)
  print, strtime[0]
  readcdf_var_to_cdfi_var, cdfi, 'strtime', reform( strtime, [1, nepoch] ), nepoch

 ;---pds_sclk_time: string [times]
  cdfi.g_attributes.pds_sclk_start_count = mmo_utc2sclk(strtime[0])
  cdfi.g_attributes.pds_sclk_stop_count = mmo_utc2sclk(strtime[n_elements(strtime)-1])

 ;---mdp_ti: ulong [times]
  readcdf_var_to_cdfi_var, cdfi, 'mdp_ti', l1dat['Variables', 'mdp_ti', 'VarData'], nepoch

 ;---Time width is calculated from a differencce between 'epoch_delta2' and 'epoch_delta1'. 
  edt = l1dat['Variables', 'epoch_delta2', 'VarData']
  stt = l1dat['Variables', 'epoch_delta1', 'VarData']
  dt = edt - stt
  readcdf_var_to_cdfi_var, cdfi, 'time_width', dt, nepoch

 ;---frequency: [times, pts]
  readcdf_var_to_cdfi_var, cdfi, 'spec_freq', l1dat['Variables', 'spec_freq', 'VarData'], nepoch
    
 ;---Spectral width: [times, pts]
  readcdf_var_to_cdfi_var, cdfi, 'spec_width', l1dat['Variables', 'spec_width', 'VarData'], nepoch

 ;---Spectral average and peak data of Eu and Ev: [times, pts]
  readcdf_var_to_cdfi_var, cdfi, 'Ex_power_ave', l1dat['Variables', 'Ex_power_ave', 'VarData'], nepoch
  readcdf_var_to_cdfi_var, cdfi, 'Ey_power_ave', l1dat['Variables', 'Ey_power_ave', 'VarData'], nepoch
  readcdf_var_to_cdfi_var, cdfi, 'eu_spectra_peak', l1dat['Variables', 'Eu_spectra_peak', 'VarData'], nepoch
  readcdf_var_to_cdfi_var, cdfi, 'ev_spectra_peak', l1dat['Variables', 'Ev_spectra_peak', 'VarData'], nepoch

 ;---Corrected time index: [times, pts]
   readcdf_var_to_cdfi_var, cdfi, 'ti_corrected', l1dat['Variables', 'ti_corrected', 'VarData'], nepoch
   
 ;---Quality flag: [times, pts]
  readcdf_var_to_cdfi_var, cdfi, 'quality_flag', l1dat['Variables', 'EFD_quality_flag', 'VarData'], nepoch
    
  if debug then dprint, 'Finished populating the cdfi structure' 

  return
end

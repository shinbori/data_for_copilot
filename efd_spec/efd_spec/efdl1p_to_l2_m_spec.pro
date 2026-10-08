;+
; PRO efdl1p_to_l2_m_spec
;
; :Description:
;    Read EFD L1 prime CDF data and json file and put L1 prime data value into L2 data.
;
; :Params:
;
; :Keywords:
; outdatadir: Directory in which the CDF data file is saved
; cdfdeffpath: File path of the master CDF table in csv 
;
; :Examples:
; IDL> makecdf_mmo_pwi_efd_l2_m_spec, 20181110, cdfi
; 
; :History:
; 2024/03/18: Just drafted. 
; 
;
; :Author:
; Atsuki Shinbori, ISEE (shinbori at isee.nagoya-u.ac.jp)
;
;-

pro efdl1p_to_l2_m_spec, date, cdfi, gitinfo = gitinfo, $
                          versionstr = versionstr, l1pdat = l1pdat, debug = debug

   if ~keyword_set(debug) then debug = 0 ;; For debugging
  
   if n_params() ne 2 then return

   if ~is_struct(cdfi) then begin
      dprint, 'the given cdfi structure is not a structure!'
      return
   endif

   mmocdf_init

  ;---Load Lv1 prime etall data and others
  ;---e.g., data/chs/satellite/mmo/l1sample/pwi/efd/l1/Spec/2018/11/bc_mmo_pwi-efd_l1p_l-spec_20181110_r01-v00-00.cdf
   if typename(l1pdat) ne 'ORDEREDHASH' then begin
     ;---File path of a Lv.1 data 
      l1prootdir = '/home/miosc/mio-sc/work_local/data_org/bc/mmo/'  ;;!mmocdf.dat_org_dir
      ts = time_struct( string(date) )
      syyyy = string(ts.year, '(I04)') + '/' ;; 2018/
      syyyymm = string(ts.year, '(I04)') + '/' + string(ts.month, '(I02)') + '/' ;; 2018/03/
      symd = strtrim( string(date), 2 )
      l1pfpath = l1prootdir + 'pwi/efd/l1_prime/' + syyyy + 'bc_mmo_pwi-efd_l1p_m-spec_'+symd+'_r01-v00-00.cdf'

     ;---Read Lv.1 prime data and store them in a hash
      if ~file_test( l1pfpath ) then begin
         dprint, 'Cannot find a Lv.1 prime data file!  --> ' + l1pfpath
         return
      endif
    
     ;---CDF ver. 3.8.1 or newer is needed to use cdf_readcdf().
      l1pdat = cdf_readcdf(l1pfpath)
      if typename(l1pdat) ne 'ORDEREDHASH' then begin
         dprint, 'Lv.1 prime data was not normally stored in an ordered hash!'
         dprint, 'Failed to create a Lv.2 CDF file!'
         return
      endif
   endif

  
  ;---Extract the file name of the source Lv.1 prime data
   l1pfname = file_basename( l1pdat['CDFInfo','FileName'] )
   src_file_list = [ l1pfname ]
 

  ;---Get the source code name and rev. number
   get_script_info_git, gitinfo = gitinfo


  ;========Populate g-attributes in a data structure for Lv.2 pre data============
  
   if debug then dprint, 'Putting g-attrs'
  
  ;---Name of CDF file
   cdfnm_tmpl = cdfi.filename  ;; bc_mmo_pwi-efd_l2_m-spec_YYYYMMDD_rXX-vXX-XX.cdf
   if debug then dprint, 'before :'+cdfnm_tmpl

  ;---Divide a file name template into prefix + the ymd+ver part
   prefix = strmid( cdfnm_tmpl, 0, strpos( cdfnm_tmpl, '_YYYYMMDD' )+1 ) ;; bc_mmo_pwi-efd_l2_m-spec_
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
   l1pgatts = l1pdat['GlobalAttrs']
   keys = ['START_TI', 'END_TI', 'DATA_START_TIME', 'DATA_END_TIME', 'PDS_LOGICAL_IDENTIFIER']
   prefix = 'urn:jaxa:darts:bc_mmo_pwi:data_calibrated_efd:bc-mmo-pwi_cal_sc_efd_l2_m-e_spec_'
   ymdver = strtrim(string(date),2) ;; YYYYMMDD
   cdfi.g_attributes.PDS_logical_identifier = prefix + ymdver ;---PDS_logical_identifier
   cdfi.g_attributes.TITLE = cdfi.g_attributes.title ;---TITLE
   cdfi.g_attributes.PDS_COLLECTION_ID = 'urn:jaxa:darts:bc_mmo_pwi:data_calibrated_efd' ;---PDS_COLLECTION_ID

  ;---Start and end time of data
   strtime = strmid(CDF_ENCODE_TT2000( l1pdat['Variables', 'epoch', 'VarData'] ), 0, 26)
  
   if l1pgatts.haskey('START_TI') then begin
      cdfi.g_attributes.start_ti = ( l1pgatts['START_TI'] )[0]
   end else begin
      cdfi.g_attributes.start_ti = (l1pdat['Variables', 'mdp_ti', 'VarData'])[0]
   endelse

   if l1pgatts.haskey('END_TI') then begin
      cdfi.g_attributes.end_ti = ( l1pgatts['END_TI'] )[0]
   endif else begin
      cdfi.g_attributes.end_ti = (l1pdat['Variables', 'mdp_ti', 'VarData'])[n_elements((l1pdat['Variables', 'mdp_ti', 'VarData']))-1]
   endelse

  ;---Information of the source file to generate the L2 CDF file
   cdfi.g_attributes.source_file = 'bc_mmo_pwi-efd_l1p_m-spec_'+symd+'_r01-v00-00.cdf'

  ;---Start and end time of data
   unixt = time_double(reform(l1pdat['Variables', 'epoch', 'VarData']), /tt2000)
   start_time_str = time_string(unixt[0], tfor = 'YYYY-MM-DDThh:mm:ss.ffffffZ')
   end_time_str = time_string(unixt[-1], tfor = 'YYYY-MM-DDThh:mm:ss.ffffffZ')
  
  ;---Data start and end time 
   cdfi.g_attributes.data_start_time = start_time_str
   cdfi.g_attributes.data_end_time = end_time_str

  ;---PDS start and end time of data
   cdfi.g_attributes.pds_start_time = start_time_str
   cdfi.g_attributes.pds_stop_time = end_time_str
  
  ;---Source files and ancillary files
   src_files = strjoin( file_basename(src_file_list), ' ' )
   cdfi.g_attributes.source_file = src_files
 
  ;---Ancillary file is empty (actually 1 blank space) currently
   anc_files = ' '  
   cdfi.g_attributes.ancillary_file = anc_files

  ;---Data version
   cdfi.g_attributes.data_version = sverno
   
  ;---PDS version identifier
   major_ver = fix(strmid(sverno, 5, 2)) 
   minor_ver = fix(strmid(sverno, 8, 2))
   cdfi.g_attributes.pds_version_identifier = strtrim(string(major_ver), 2) + '.' + strtrim(string(minor_ver), 2)
   
  ;---the Rules of use is unchanged from the on in the data def. table

  
  ;=======Put PWI-EFD L1 prime data arrays in a data structure for Lv.2 data=======

  ;---Variable list:
  ;---epoch strtime time_width mdp_ti 
  
  ;---Put Lv1 prime data values in the cdfi structure
   if debug then dprint, 'Now putting PWI-EFD L1 prime data in L2 data structure ...'
   nepoch = n_elements( l1pdat['Variables','epoch','VarData'] )
   nepoch_tmp = nepoch 

   varnames = cdfi.vars.name
  
  ;---epoch: long64 [times]
   readcdf_var_to_cdfi_var, cdfi, 'epoch', l1pdat['Variables', 'epoch', 'VarData'], nepoch

  ;---str_time: string [times]
   strtime = strmid(CDF_ENCODE_TT2000( l1pdat['Variables', 'epoch', 'VarData'] ), 0, 26) + 'Z' ; epoch time to unix time (string)
   readcdf_var_to_cdfi_var, cdfi, 'strtime', reform( strtime, [1, nepoch] ), nepoch

  ;---PDS SCLK start and end time of data
  ;---Note that currently the SCLK file path is hard-coded here.
   sclk_strs = mmo_utc2sclk([start_time_str, end_time_str],tmp_sclk_fpath='~/work_local/data_org/spice/bc/kernels/sclk/bc_mmo_stre_20250305_v01.tsc',debug=debug, files = files)
   sclk_files = files
   for i = 0, n_elements(sclk_files) -1 do begin
      parts = strsplit(sclk_files[i], '/', /extract)
      filename = parts[-1] 
      if i eq 0 then append_array, cdf_in_sclk_file, filename + ', '
      if i gt 0 and i lt n_elements(sclk_files) - 2 then append_array, cdf_in_sclk_file, filename + ', '
      if i eq n_elements(sclk_files) - 2 then cdf_in_lsk_file = filename
      if i eq n_elements(sclk_files) - 1 then append_array, cdf_in_sclk_file, filename
   endfor
   cdf_in_sclk_file = strjoin(cdf_in_sclk_file, " ")
   
   cdfi.g_attributes.spice_kernels = cdf_in_sclk_file
   cdfi.g_attributes.leapseconds_kernel = cdf_in_lsk_file   
   cdfi.g_attributes.pds_sclk_start_count = sclk_strs[0] + '000'
   cdfi.g_attributes.pds_sclk_stop_count = sclk_strs[1]  + '000'

  ;---mdp_ti: ulong [times]
   readcdf_var_to_cdfi_var, cdfi, 'mdp_ti', l1pdat['Variables', 'mdp_ti', 'VarData'], nepoch

  ;---Time width is calculated from a differencce between 'epoch_delta2' and 'epoch_delta1'. 
   edt = l1pdat['Variables', 'epoch_delta2', 'VarData']
   stt = l1pdat['Variables', 'epoch_delta1', 'VarData']
   dt = edt - stt
   dt_arr = fltarr(nepoch)
   dt_arr [*]= dt
   readcdf_var_to_cdfi_var, cdfi, 'time_width', reform( dt_arr, [1, nepoch] ), nepoch

  ;---frequency: [times, pts]
   readcdf_var_to_cdfi_var, cdfi, 'spec_freq', l1pdat['Variables', 'spec_freq', 'VarData'], nepoch
    
  ;---Spectral width: [times, pts]
   readcdf_var_to_cdfi_var, cdfi, 'spec_width', l1pdat['Variables', 'spec_width', 'VarData'], nepoch

  ;---Spectral average and peak data of Eu and Ev: [times, pts]
   readcdf_var_to_cdfi_var, cdfi, 'Eu_power', l1pdat['Variables', 'Eu_power', 'VarData'], nepoch
   readcdf_var_to_cdfi_var, cdfi, 'Ev_power', l1pdat['Variables', 'Ev_power', 'VarData'], nepoch

  ;---Spin period: [times, pts]
   readcdf_var_to_cdfi_var, cdfi, 'spinperiod', l1pdat['Variables', 'spinperiod', 'VarData'], nepoch

  ;---Spin phase: [times, pts]
  ;readcdf_var_to_cdfi_var, cdfi, 'spinphase', l1pdat['Variables', 'spinphase', 'VarData'], nepoch
   
  ;---BIAS level: [times, pts]
   readcdf_var_to_cdfi_var, cdfi, 'BIAS_LVL_U1', l1pdat['Variables', 'BIAS_LVL_U1', 'VarData'], nepoch
   readcdf_var_to_cdfi_var, cdfi, 'BIAS_LVL_U2', l1pdat['Variables', 'BIAS_LVL_U2', 'VarData'], nepoch
   readcdf_var_to_cdfi_var, cdfi, 'BIAS_LVL_V1', l1pdat['Variables', 'BIAS_LVL_V1', 'VarData'], nepoch
   readcdf_var_to_cdfi_var, cdfi, 'BIAS_LVL_V2', l1pdat['Variables', 'BIAS_LVL_V2', 'VarData'], nepoch
   
  ;---Quality flag: [times, pts]
   readcdf_var_to_cdfi_var, cdfi, 'quality_flag', l1pdat['Variables', 'quality_flag', 'VarData'], nepoch
  
  ;---Quality level: [times, pts]
   readcdf_var_to_cdfi_var, cdfi, 'quality_level', l1pdat['Variables', 'quality_level', 'VarData'], nepoch  
    
   if debug then dprint, 'Finished populating the cdfi structure' 

   return
end


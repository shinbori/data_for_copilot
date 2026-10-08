;+
; PRO makecdf_mmo_pwi_efd_l2_l_spec
;
; :Description:
;    Make a level-2 l-mode electric field spectrum data file of PWI/EFD in CDF
;
; :Params:
;
; :Keywords:
; outdatadir: Directory in which the CDF data file is saved
; cdfdeffpath: File path of the master CDF table in csv 
;
; :Examples:
; IDL> makecdf_mmo_pwi_efd_l2_l_spec,  20181110
; 
; :History:
; 2024/03/18: Just drafted. 
;
; :Author:
; Atsuki Shinbori, ISEE (shinbori at isee.nagoya-u.ac.jp)
;
;-

pro makecdf_mmo_pwi_efd_l2_l_spec, date, $
                                   cdfdeffpath = cdfdeffpath, outcdfdir = outcdfdir, $
                                   versionstr = versionstr, cdfi = cdfi, debug = debug, local = local
 
  ;---Initialize CDF environment
   cdf_leap_second_init

  ;---Check keyword
   if undefined(debug) then debug = 0    
   if not keyword_set(date) then date = 20181110L
 
  ;---Set time span 
   timespan, string(date)

  ;---Set JSON file
   if ~keyword_set(cdfdeffpath) then begin
      cdfdeffname = 'bc_mmo_pwi-efd_l2_l-spec_v01_00.json'
      cdfdeffpath = file_source_dirname() + '/cdf_definition/' + cdfdeffname
   endif
   if ~file_test(cdfdeffpath) then begin
      dprint, 'Cannot find the CDF definition JSON file! :'+cdfdeffpath
      dprint, 'EXIT!!'
      return
   endif
   print, 'CDF definition in json: '+cdfdeffpath
  
  ;---Set CDF Directory  
   if ~keyword_set(outcdfdir) then begin
      if ~keyword_set(local) then begin
         mmocdf_init
        ;; !mmocdf.cdf_repo_dir = '/var/www/html/data/chs/satellite/mmo/pwi/efd/'
        ;; outcdfdir = !chscdf.cdf_repo_dir
        ;;+'satellite/mmo/cdf/pwi/efd/l2/l/spec/'
      endif else begin
         mmocdf_init, cdf_repo_dir = file_source_dirname() + '/data/chs/satellite/mmo/cdf/', $
                       dat_org_dir = '~/work_local/data_org/bc/mmo/pwi/efd/l1_prime/'
      endelse
      outcdfdir = !mmocdf.cdf_repo_dir  + 'pwi/efd/l2/l/spec/'
    
   endif
   date_char = string(format = '(i8.8)', date)
   dir_cdf = spd_addslash(outcdfdir) + strmid(date_char, 0, 4)+'/'+strmid(date_char, 4, 2)+'/' ;; YYYY/MM/
   print, 'Directory in which CDF files are saved: '+dir_cdf

  ;---Read JSON file
   print, '... READING THE JSON FILE FOR CDF ATTRIBUTES AND VARIABLES...'
   cdfdef_json_to_cdfidat, json_fpath=cdfdeffpath, cdfidat=cdfi
   if debug then help, cdfi

  ;---Make EFD spec L2 data structure
   if debug then dprint, '... running EFDL1p_TO_L2_L-SPEC ...'
   efdl1p_to_l2_l_spec, date, cdfi, gitinfo = gitinfo_efdl1p, versionstr = versionstr, debug = debug

  ;---Add some G-ATTRIBUTES - - -
  ; ;;; Consolidate all information on programs used for the data file generation
   get_script_info_git, gitinfo = gitinfo, /get_repo_ver
   software_ver = gitinfo.tagnm
   gitstr = gitinfo.fname_revno_str + ', ' + gitinfo_efdl1p.fname_revno_str
   cdfi.g_attributes.software_version = '1.0' ;software_ver
   if debug then begin
      print, 'GENERATION_SOFTWARE: ' + cdfi.g_attributes.generation_software
      print, 'SOFTWARE_VERSION: ' + software_ver
      print, 'GENERATION_CODE: ' + gitstr
      print, 'SOURCE_FILE: ' + strjoin(cdfi.g_attributes.source_file)
   endif
   
  ;---Generation date
   cdfi.g_attributes.generation_date = time_string( systime(/sec), tfor='YYYYMMDD' )

  ;---Store level-2 data info CDF file
   print, '... CREATING CDF FILES ...'
   cdffn = cdfi.filename
   cdfpath = dir_cdf + cdffn
   file_mkdir, dir_cdf
   dummy = cdf_save_vars3( cdfi, cdfpath )

   print, cdfpath+' has been Created.'

   if debug then dprint, verbose=verbose, 'Clean up the cdfi structure with many heaps' ;bpif keyword_set(all) eq 0
   tplot_ptrs = ptr_extract(tnames(/dataquant))
   unused_ptrs = ptr_extract(cdfi, except=tplot_ptrs)
   ptr_free, unused_ptrs

end 

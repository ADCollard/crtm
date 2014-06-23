;+
; Helper function to subtract two oSRF objects..
;
;  diff_oSRF = oSRF_Subtract(left_oSRF, right_oSRF)
;-

FUNCTION oSRF_Subtract, left, right, $
  Debug = debug


  ; Set up
  COMPILE_OPT HIDDEN
  ; ...OSRF parameters
  @osrf_parameters
  ; ...Set up error handler
  @osrf_func_err_handler

  ; Exit if:
  ; ...Both arguments are not oSRF objects
  IF ( (~ ISA(left,'oSRF')) || (~ ISA(right,'oSRF')) ) THEN RETURN, !NULL
  ; ...Both arguments are not allocated
  IF ( (~ left->Associated(Debug=debug)) || (~ right->Associated(Debug=debug)) ) THEN RETURN, !NULL


  ; Check the gross congruency of the left and right
  left.Get_Property, $
    Debug            = debug           , $
    n_Bands          = n_bands         , $
    Sensor_Id        = sensor_id       , $
    WMO_Satellite_ID = wmo_satellite_id, $
    WMO_Sensor_ID    = wmo_sensor_id   , $
    Sensor_Type      = sensor_type     , $
    Channel          = channel         , $
    Integral         = integral        , $
    Flags            = flags           , $
    f0               = f0              , $
    n_Points         = n_points
  right.Get_Property, $
    Debug            = debug                 , $
    n_Bands          = right_n_bands         , $
    Sensor_Id        = right_sensor_id       , $
    WMO_Satellite_ID = right_wmo_satellite_id, $
    WMO_Sensor_ID    = right_wmo_sensor_id   , $
    Sensor_Type      = right_sensor_type     , $
    Channel          = right_channel         , $
    n_Points         = right_n_points
  ; ...Same sensor/channel?
  IF ( n_bands          NE right_n_bands          OR $
       sensor_id        NE right_sensor_id        OR $
       wmo_satellite_id NE right_wmo_satellite_id OR $
       wmo_sensor_id    NE right_wmo_sensor_id    OR $
       sensor_type      NE right_sensor_type      OR $
       channel          NE right_channel          ) THEN BEGIN
    MESSAGE, 'oSRF objects do not match', /INFORMATIONAL
    RETURN, !NULL
  ENDIF
  ; ...Same point numbering? Output info if not.
  IF ( ~ ARRAY_EQUAL(n_points, right_n_points) ) THEN $
    MESSAGE, 'oSRF objects have different number of points. ' + $
             'Attempting to match frequencies...', /INFORMATIONAL


  ; Get the matching frequency indices
  left_idx  = HASH()
  right_idx = HASH()
  frequency = HASH()
  n_points  = LONARR(n_bands)

  FOR band = 1, n_bands DO BEGIN

    IF ( n_bands GT 1 ) THEN $
      cband = " band " + STRTRIM(band,2) $
    ELSE $
      cband = ""
 
    ; Get band frequency data
    left.Get_Property, $
      band, $
      Frequency  = left_f, $
      Debug      = debug
    right.Get_Property, $
      band, $
      Frequency  = right_f, $
      Debug      = debug


    ; Get the encompassing frequency bounds
    f1 = MIN(left_f) > MIN(right_f)
    f2 = MAX(left_f) < MAX(right_f)
    
    idx = WHERE((left_f GE f1) AND (left_f LE f2), left_count)
    IF ( left_count EQ 0 ) THEN BEGIN
      MESSAGE, 'Left oSRF object' + cband + ' has no matching frequencies', /INFORMATIONAL
      RETURN, !NULL
    ENDIF
    left_avgdf = MEAN(left_f[idx[1:-1]] - left_f[idx[0:-2]], /DOUBLE)
    
    idx = WHERE((right_f GE f1) AND (right_f LE f2), right_count)
    IF ( right_count EQ 0 ) THEN BEGIN
      MESSAGE, 'Right oSRF object' + cband + ' has no matching frequencies', /INFORMATIONAL
      RETURN, !NULL
    ENDIF
    right_avgdf = MEAN(right_f[idx[1:-1]] - right_f[idx[0:-2]], /DOUBLE)
    
    ; Check the count...
    IF ( left_count NE right_count ) THEN BEGIN
      MESSAGE, 'oSRF objects' + cband + ' frequency match failed', /INFORMATIONAL
      RETURN, !NULL
    ENDIF
    ; ...and average frequency interval (not sure if this will work for microwave)
    IF ( ABS(left_avgdf-right_avgdf) GT (MACHAR(/DOUBLE)).EPS ) THEN BEGIN
      MESSAGE, 'oSRF objects' + cband + ' frequency intervals are different', /INFORMATIONAL
      RETURN, !NULL
    ENDIF

    ; Construct an array with ALL the frequencies
    f = [left_f, right_f]
    f = f[UNIQ(f,SORT(f))]
    frequency[band] = f
    
    ; Save the band point count for allocation
    n_points[band-1] = N_ELEMENTS(f)

    ; Now get the indices to slot in SRF to ALL-frequency array
    left_idx[band] = WHERE(f GE left_f[0]  AND f LE left_f[-1] , left_count)
    IF ( left_count EQ 0 ) THEN BEGIN
      MESSAGE, 'Left oSRF object' + cband + ' full index slot determination failed', /INFORMATIONAL
      RETURN, !NULL
    ENDIF
    right_idx[band] = WHERE(f GE right_f[0] AND f LE right_f[-1], right_count)
    IF ( left_count EQ 0 ) THEN BEGIN
      MESSAGE, 'Right oSRF object' + cband + ' full index slot determination failed', /INFORMATIONAL
      RETURN, !NULL
    ENDIF
    
  ENDFOR
    

  ; Create the return object
  diff = OBJ_NEW('oSRF')
  diff.Allocate, n_points, Debug = debug
  ; ...Fill in the various id bits
  diff.Set_Property, $
    Debug            = debug           , $
    Sensor_Id        = sensor_id       , $
    WMO_Satellite_ID = wmo_satellite_id, $
    WMO_Sensor_ID    = wmo_sensor_id   , $
    Sensor_Type      = sensor_type     , $
    Channel          = channel
  

  ; Difference the response data
  FOR band = 1, n_bands DO BEGIN

    ; Get band data
    left.Get_Property, $
      band, $
      Response = left_r, $
      Debug    = debug
    right.Get_Property, $
      band, $
      Response = right_r, $
      Debug    = debug


    ; Slot the response spectra into the full frequency arrays
    left_response  = DBLARR(n_points[band-1])
    left_response[left_idx[band]] = left_r
    
    right_response = DBLARR(n_points[band-1])
    right_response[right_idx[band]] = right_r
    

    ; Difference them
    diff.Set_Property, $
      band, $
      Frequency = frequency[band]               , $
      Response  = left_response - right_response, $
      Debug     = debug
    
  ENDFOR


  ; Difference the temperature data for the polychromatic fit
  left.Get_Property, $
    poly_Tdata = t, $
    Debug      = debug
  right.Get_Property, $
    poly_Tdata = right_t, $
    Debug      = debug
  t["Teff"] = t["Teff"] - right_t["Teff"]
  t["Tfit"] = t["Tfit"] - right_t["Tfit"]
  

  ; Set some components explicitly
  diff.Set_Property, $
    Debug      = debug   , $
    Integral   = integral, $
    Flags      = flags   , $
    f0         = f0      , $
    poly_Tdata = t       , $
    /Special


  ; Set the difference flag
  diff.Set_Flag, /Is_Difference
  
    
  ; Done
  RETURN, diff

END

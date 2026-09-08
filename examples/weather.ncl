; Synthetic weather workflow based on the supplied NCL snippets.
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"

function anomaly(x[*][*]:numeric, baseline:numeric)
local result
begin
  result = x - baseline
  result@long_name = "Temperature anomaly"
  return(result)
end

begin
  f = addfile("temperature.nc", "r")
  varname = "T"
  t = f->$varname$(0, {20:50}, {100:130})
  t!0 = "lat"
  t!1 = "lon"
  lat = t&lat
  subset = t(lat|:, lon|::-1)
  field := anomaly(t, 273.15)

  png = "png"
  png@wkWidth = 1600
  png@wkHeight = 1200
  wks = gsn_open_wks(png, "temperature")
  panel_dims = (/1, 2/)
  plots = new(sum(panel_dims), "graphic")
  res = True
  res@cnFillOn = True
  res@cnLevelSelectionMode = "ManualLevels"
  res@cnMinLevelValF = -10.d0
  res@cnMaxLevelValF = 30.d0
  res@tiMainString = "Temperature; print is text here"

  do i = 0, 1
    if (any(ismissing(field))) then
      print("Missing data")
    else if (i.eq.0) then
      plots(i) = gsn_csm_contour_map(wks, field, res)
    else
      plots(i) = gsn_csm_contour_map(wks, t, res)
    end if
    end if
  end do
  gsn_panel(wks, plots, panel_dims, True)
  draw_China_shapefile(wks, plots(0), res)
end

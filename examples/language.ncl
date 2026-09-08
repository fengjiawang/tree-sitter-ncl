/; NCL block comment.
   begin, "strings", and function names are comment text.
;/
external mathlib "./mathlib.so"

procedure describe(x:numeric)
local message
begin
  message = "value: " + tostring(x)
  print(message)
  return
end

begin
  a = (/1b, 2B, 3h, 4H, 5i, 6I, 7l, 8L, 9q, 10Q/)
  b = (/1., .5, 1.e3, 1d, 2.5D-4/)
  c = (/ (/1, 2/), \
         (/3, 4/) /)
  bag = [/ a, b, "NCL" /]
  first = bag[0]
  x = -3^2^2 + c#c
  ok = 1.eq.1 .and. .not. False
  do while (ok)
    mathlib::transform(x)
    ok = False
    continue
  end do
  do while (ok)
    break
  end do
  obj = create "canvas" cairoWindowWorkstationClass defaultapp
    "wkWidth" : 800
    "wkHeight" : 600
  end create
  setvalues obj
    "wkWidth" : 1024
  end setvalues
  getvalues obj
    "wkWidth" : width
  end getvalues
  f = addfile("groups.nc", "r")
  group_ref = f=>physics
  x = group_ref->$"temperature"$({lat|20:50}, {lon|100:130})
  x@$"units"$ = "K"
  x&$"lat"$ = (/20, 30, 40, 50/)
end

using SimplePIE
using Unitful
using Unitful: Å, nm, μm, °, kV, mrad, pA

α = 3.17mrad
N = [256, 256]
dₛ = 32.55Å
Δf = -3.0μm
D = 84 #40cm camera length

λ = wavelength(300kV)
Δk = 2α / D
θ = N * Δk
Δx, Δy = uconvert.(Å, λ./θ)
Δx * N[1]
rₚ = probe_radius(α, Δf)
Δx * N[1] > rₚ * 1.3
sₚ = probe_area(α, Δf)
overlap, overlap_ratio = probe_overlap(rₚ, dₛ; ratio=true)

function dose(i, t, dₛ)
    uconvert(u"Å^-2", i * t / 1.62e-19u"C" / dₛ^2)
end

i = 1.0pA
t = 500u"μs"
d = dose(i, t, dₛ)

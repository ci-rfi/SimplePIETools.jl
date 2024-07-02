using DrWatson
@quickactivate "PROJECT_NAME"
using Distributed
using SimplePIE
using Unitful
using Unitful: Å, nm, μm, °, kV, mrad
using Configurations
using Plots
using Dates
using HDF5
using Statistics: mean
using Images
using TensorBoardLogger
using Logging
using HTTP
using JSON
using Medipix

session = "SESSION_DATE"
sample_name = "SAMPLE_001"
cl_aperture = "CLApt2-2"
magnification = "120K"
camera_length = "80cm"
Δf = -1.0μm # Defocus (μm)
ht_focus_ratio = -28.7u"V/µm" # HT-focus ratio when using voltage to control focus(eV/µm)
scan_size = 512
block_size = 128
α = 0.91mrad # Convergence semi-angle (mrad)
dₛ = 32.55Å # Step size (Å)
θᵣ = -90.0° # Rotation angle (degree)
D = 112 # CBED diameter (pixel)
nᵢ = 1 # Number of iterations for the test reconstruction
notes = "XAu dataset for calibration"

edm_ip = ip"172.22.73.9"
medipix_ip = ip"172.22.73.9"
qdscan_python_exe = "c:/Users/Merlin/Desktop/scan_engine_testing/test_env/Scripts/python.exe"
qdscan_script_dir = "c:/Users/Merlin/Desktop/ScanEngine/ruska"
qdscan_script = "medipix_raster_acquisition_$(scan_size)x$(scan_size).py"

# Medipix settings
cmds = [set_continuousrw(1), # 1: True, 0: False
        set_counterdepth(6),
        set_acquisitiontime(0.001), # Any value smaller than the scan signal period is ok.
        set_acquisitionperiod(0.001), # Any value smaller than the scan signal period is ok.
        set_scanx(scan_size),
        set_scany(scan_size),
        set_triggerstart(1), # 1: Rising edge
        set_triggerstop(1), # 1: Rising edge
        set_runheadless(0), # 1: True, 0: False
        set_fileenable(0), # 1: True, 0: False
        set_selectchips(8), # Four individual chips: 1, 2, 4, or 8; all chips: 15
        set_scantriggermode(0)]

# Test reconstruction 
run_test_reconstruction_after_acquisition = true
block_id = 1 # Choose a block for test reconstruction
frame_id = 100 # Choose a frame for visualization

## Acquisition
# EDM control
response = HTTP.put("http://$edm_ip:4337/EDM/SignalCombinerHardware/EnableB3", body=JSON.json(Dict("EnableB3" => true)))
response = HTTP.put("http://$edm_ip:4337/EDM/ModulationSettings/EnableModulation", body=JSON.json(Dict("EnableModulation" => false)))

# Medipix control
m = MedipixConnection(medipix_ip)
send_cmd(m, cmds; verbose=true)

data_timestamp = Dates.format(now(), "yyyymmdd_HHMMSS")
dirname = datadir("exp_raw", session, data_timestamp)
mkdir(dirname)
filename = joinpath(dirname, sample_name)
pd = make_pid_dict(scan_size, block_size) # Process id dictionary

print("""

New dataset: $data_timestamp

----------------------------------------------------
# Final check before acquisition
----------------------------------------------------
- Defocus ($(ht_focus_ratio*Δf) for $(Δf))
- Magnification: $magnification
- ADF out
- K2/Orius out
- Camera length: $camera_length
- Screen up
- CBED centering
- Beam blanking (unblank after EDM setup)
- Gatan SPOT
- Reset QD Scan if necessary
----------------------------------------------------

# When ready, press "ENTER" and start the scan.

""")
readline()

lg=TBLogger(datadir("exp_raw", session, "tensorboard_logs/" * data_timestamp), min_level=Logging.Info)

with_logger(lg) do
    @info "ptycho_acquisition" session=session
    @info "ptycho_acquisition" sample_name=sample_name
    @info "ptycho_acquisition" cl_aperture=cl_aperture
    @info "ptycho_acquisition" magnification=magnification
    @info "ptycho_acquisition" camera_length=camera_length
    @info "ptycho_acquisition" defocus=string(ustrip(Δf |> μm)) * "μm"
    @info "ptycho_acquisition" scan_size=string(scan_size) * "scan",
    @info "ptycho_acquisition" block_size=string(block_size) * "block",
    @info "ptycho_acquisition" medipix_cmds=TBText(cmds)
    @info "ptycho_acquisition" notes=notes
end

@async begin
    sleep(2) # Wait for Medipix to arm
    ssh_command = `ssh merlin@$medipix_ip powershell $qdscan_python_exe $qdscan_script_dir/$qdscan_script`
    run(ssh_command)
end

run_acquisition(m, filename; verbose=true, nfiles=length(unique(pd)), file_indices=pd)

## Reconstruction
block_str = lpad(string(block_id), 3, "0")
datafiles = readdir(datadir("exp_raw", session, data_timestamp), join=true)
datafile = datafiles[block_id]

dps = load_cbeds(load_h5, datafile; align=false)

try
    global dps = align_cbeds(dps; crop=false)
catch
    println("CBED alignemnt failed.")
end

with_logger(lg) do
    @info "ptycho_acquisition/"*block_str*"/data" example_frame = heatmap(dps[frame_id], aspect_ratio=:equal)
end

N = collect(size(dps[frame_id]))
n = [block_size, block_size]
λ = wavelength(300kV)
Δk = 2α / D
θ = N * Δk
Δx, Δy = uconvert.(Å, λ./θ)
rₚ = probe_radius(α, Δf)
sₚ = probe_area(α, Δf)
overlap, overlap_ratio = probe_overlap(rₚ, dₛ; ratio=true)
scaling_factor = probe_scaling_factor(mean(dps))

data_params = DataParams(projectname(), session, datadir(), datafile, string(now()),
                        N, n, λ, α, Δk, θ, θᵣ, dₛ, Δx, Δf, rₚ, sₚ,
                        overlap, overlap_ratio, scaling_factor)

recon_timestamp = Dates.format(now(), "yyyymmdd_HHMMSS")
recon_params = ReconParams(; iteration_start=1, iteration_end=nᵢ, alpha=0.01, beta=0.01,
                                filename=datadir("exp_pro", session, join([sample_name, "data", data_timestamp, "recon", recon_timestamp], "_") * ".h5"),
                                object_name=join(["block", block_str, "iteration", string(nᵢ)], "_"), probe_name=join(["block", block_str, "iteration", string(nᵢ)], "_"))

data_params_toml = to_toml(data_params)
map(x -> h5write(x, "/data_params", data_params), datafiles)
acquisition_script = read(@__FILE__, String)
map(x -> h5write(x, "/acquisition_script", acquisition_script), datafiles)
open(joinpath(dirname, "data_params.toml"), "w") do file
    print(file, data_params_toml)
end
with_logger(lg) do
    @info "ptycho_reconstruction/"*block_str data_params=TBText(split(data_params_toml, '\n'))
end

if run_test_reconstruction_after_acquisition
    println("Running test reconstruction...")

    recon_params_toml = to_toml(recon_params)
    open(joinpath(dirname, "recon_params_$recon_timestamp.toml"), "w") do file
        print(file, recon_params_toml)
    end
    with_logger(lg) do
        @info "ptycho_reconstruction/"*block_str recon_params=TBText(split(recon_params_toml, '\n'))
    end

    𝒜 = make_amplitude(dps)
    𝒪, ℴ = make_object(data_params)
    𝒫 = make_probe(data_params)
    ptycho_reconstruction!(𝒪, ℴ, 𝒫, 𝒜, data_params, recon_params)

    save_result(𝒪, 𝒫, data_params, recon_params)
    ENV["GKSwstype"]="nul"
    with_logger(lg) do
        @info "ptycho_reconstruction/"*block_str*"/images" phase = phase_image(𝒪)
        @info "ptycho_reconstruction/"*block_str*"/images" amplitude = amplitude_image(𝒪)
        @info "ptycho_reconstruction/"*block_str*"/figures" phase = plot_phase(𝒪, size=(1000, 1000))
        @info "ptycho_reconstruction/"*block_str*"/figures" amplitude = plot_amplitude(𝒪, size=(1000, 1000))
    end
end
println("Done.")
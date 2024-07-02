using DrWatson
@quickactivate "PROJECT_NAME"
using FileIO
using Plots
using Dates

# Save the calibration data as TIFF images in the folder `convergence_semi_angle_calibration` under the session folder.
# Rename them in the format of <date>_<camera_length>_<aperture>.tif, e.g. "20240312_80cm_CLA11.tif"
# For gold ring images, replace <aperture> with "Au", e.g. "20240312_80cm_Au.tif"
# Modify the alignment file names manually as these cannot be automated

session = "SESSION_DATE"
tem_alignemnt_file = "yyyy-mm-dd__HH-MM.jal"
cosmo_file = "yyyymmdd_300kV_NBD_mode_ptycho"
calibration_dir = datadir("exp_raw", session, "convergence_semi_angle_calibration")

filenames = filter(x -> x[end-8:end-6] == "CLA", readdir(datadir("exp_raw", session, "convergence_semi_angle_calibration"), join=true))
imgs = [Float32.(load(f)) for f in filenames]

D_gold = 1807
Δk = 8.36 * 2 / D_gold

function calculate_radius(img, Δk; threshold=0.01)
    bw = img .> threshold
    n = √(sum(bw) / pi)
    D = 2n
    return (Int(round(D)), round(n * Δk, digits=2))
end

r = calculate_radius.(imgs, Δk)

date_line = "### " * Dates.format(now(), "yyyy-mm-dd") * "\n"
tem_line = "- TEM Center Alignment File: `$tem_alignemnt_file`\n"
cosmo_line = "- COSMO Alignment File: `$cosmo_file`\n"
calibration_data_line = "- Calibration Data: `/home/ruska/Data/ssd/yyyy-mm-dd/convergence_semi_angle_calibration.dmw`\n\n"
title_line = "| Aperture  | semi-angle (mrad) | Pixels (diameter) | Camera Length | dk (mrad/pixel) |\n|-----------|-------------------|-------------------|---------------|-----------------|\n"
gold_line = "| Gold ring | 8.36              | 1808              | 80cm          | 0.00925         |\n"

aperture_names = vec(["CLA$x-$y" for y in 1:4, x in 1:2]) |> x -> pushfirst!(x, "Gold ring")
α = string.(last.(r)) |> x -> pushfirst!(x, "8.36")
D = string.(first.(r)) |> x -> pushfirst!(x, string(D_gold))
camera_length = ["80cm" for _ in 1:length(aperture_names)]
dk = [string(round(Δk, digits=8)) for _ in 1:length(aperture_names)]

lines = ["| " * join(tup, "| ") * "|\n" for tup in zip(aperture_names, α, D, camera_length, dk)]
table = date_line * tem_line * cosmo_line * calibration_data_line * title_line * join(lines)
print(table)
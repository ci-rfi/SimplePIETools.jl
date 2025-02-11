using DrWatson
using Dates
using Pkg

function get_date()
    date_string = Dates.format(today(), "yyyy-mm-dd")
    print("Date [default: $date_string]: \n\t")
    user_input = readline()
    if user_input != ""
        date_string = Dates.format(Date(user_input, "yyyy-mm-dd"), "yyyy-mm-dd")
    end
    return date_string
end

function get_project_name()
    project_name = "project_" * Dates.format(today(), "yyyymmdd")
    print("Project name [default: $project_name]: \n\t")
    user_input = readline()
    if user_input != ""
        project_name = user_input
    end
    return project_name
end

function get_project_location()
    project_location = joinpath(homedir(), "Documents", "ptycho")
    print("Project location [default: $project_location]: \n\t")
    user_input = readline()
    if user_input != ""
        project_location = user_input
    end
    return project_location
end

function get_project_folder(; max_attempts=3)
    for n in 1:max_attempts
        global project_name = get_project_name()
        global project_location = get_project_location()
        global project_folder = joinpath(project_location, project_name)

        tryagain = false
        if isdir(project_folder) && n < max_attempts
            print("Project folder $project_folder already exists. Try differnt project name and location? y/n[n]: ")
            user_input = readline()
            if user_input != ""
                tryagain = user_input == "y" || user_input == "Y" ? true : false
            end
        end

        if !tryagain
            break
        end
    end
    return project_name, project_folder
end

function create_project_folder(; max_attempts=3)
    project_name, project_folder = get_project_folder(max_attempts=max_attempts)

    print("Proceed with creating \"$project_name\" at $project_folder? y/n[y]: ")
    user_input = readline()
    proceed = user_input == "y" || user_input == "Y" || user_input == "" ? true : false

    if proceed
        try 
            initialize_project(project_folder)
            @info "Project \"$project_name\" created at $project_location."
            quickactivate(project_folder)
            Pkg.add("ArgParse")
            Pkg.add("Distributed")
            Pkg.add(url="https://github.com/ci-rfi/SimplePIE.jl")
            Pkg.add("Unitful")
            Pkg.add("Configurations")
            Pkg.add("Plots")
            Pkg.add("Dates")
            Pkg.add("HDF5")
            Pkg.add("Statistics")
            Pkg.add("Images")
            Pkg.add("TensorBoardLogger")
            Pkg.add("Logging")
            Pkg.add("Medipix")
            Pkg.add("TOML")
            Pkg.add("Random")
            Pkg.add("ImageContrastAdjustment")
            Pkg.add("HTTP")
            Pkg.add("JSON")            
            Pkg.precompile()
            Pkg.build()
            template_files = ["ptycho_acquisition_template.jl", "convergence_semi_angle_calibration_template.jl", "experimental_condition_template.jl"]
            for tf in template_files
            f = joinpath(@__DIR__, "script_templates", tf)
                open(joinpath(project_folder, "scripts", replace(tf, "_template" => "")), "w") do file
                    write(file, replace(read(f, String), "PROJECT_NAME" => project_name, "SESSION_DATE" => Dates.format(today(), "yyyy-mm-dd")))
                end
            end
        catch e
            @error "Failed to create new project \"$project_name\" at $project_location."
            @error e
        end
    else
        println("No new project created.")
    end
    return project_folder
end

function create_data_folder(project_folder; storage_path="/home/ruska/Data/ssd")
    date_string = Dates.format(today(), "yyyy-mm-dd")
    data_folder = joinpath(storage_path, date_string)
    process_folder = joinpath(storage_path, "processing", date_string)
    if isdir(project_folder)
        print("Project folder $project_folder exists. Create data folder $data_folder and processing folder $process_folder for today? y/n[y]: ")
        proceed = true
        user_input = readline()
        if user_input != ""
            proceed = user_input == "y" || user_input == "Y" ? true : false
        end

        if proceed == false
            print("Create data folder for a differet date? y/n[n]: ")
            user_input = readline()
            if user_input != ""
                proceed = user_input == "y" || user_input == "Y" ? true : false
            end
            if proceed == true
                date_string = get_date()
                data_folder = joinpath(storage_path, date_string)
            end
        end

        if proceed == true
            if !isdir(data_folder)
                mkdir(data_folder)
                @info "Data folder $data_folder created.\n"
            else
                @warn "Data folder $data_folder already exists."
            end

            data_folder_link = joinpath(project_folder, "data", "exp_raw", date_string)
            if !isdir(data_folder_link) && !islink(data_folder_link)
                symlink(data_folder, data_folder_link)
                @info "Symbolic link to $data_folder created in $data_folder_link.\n"
            else
                @warn "Symbolic link to $data_folder already exists in $data_folder_link."
            end

            if !isdir(process_folder)
                mkdir(process_folder)
                @info "Processing folder $process_folder created.\n"
            else
                @warn "Processing folder $process_folder already exists."
            end

            process_folder_link = joinpath(project_folder, "data", "exp_pro", date_string)
            if !isdir(process_folder_link) && !islink(process_folder_link)
                symlink(process_folder, process_folder_link)
                @info "Symbolic link to $process_folder created in $process_folder_link.\n"
            else
                @warn "Symbolic link to $process_folder already exists in $process_folder_link."
            end

        end
    end
end

function ptycho_init(; max_attempts=3, storage_path="/home/ruska/Data/ssd")
    project_folder = create_project_folder(max_attempts=max_attempts)
    create_data_folder(project_folder, storage_path=storage_path)
end

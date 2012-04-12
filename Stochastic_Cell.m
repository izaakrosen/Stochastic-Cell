% profile_cell.m  (beta)
% copyright: Brian Drawert 2010,2011
function profile_cell(varargin)
%     if(nargin==0)
%         input_file_mask = {...
%             'Ste20Spa2.1m.1_C001T%.3d.tif',... %red channel
%             'Ste20Spa2.1m.1_C002T%.3d.tif'};  %green channel
%         tspan=1:21;
%     else
%         %TODO: make general
%     end
    %%%%%%%%%%%%%%%%%%%%%%%%
    % global variables
    tspan=[];
    green_files={};
    red_files={};
    cell_profile_data={};
    normalization_data={};
    %%%%%%%%%%%%%%%%%%%%%%%%%
    normalization_set=0;
    dataset_savefile='';
    current_cell_selected=-1;
    %%%%%%%%%%%%%%%%%%%%%%%%%
    crop_lim=cell(1);   %crop_lim=cell_proifile_data{current_cell_selected}.crop_lim
    edgepts=[];
    cpt=[];
    %%%%%%%%%%%%%%%%%%%%%%%%%
    cur_time=1;
    fig=[];
    curve_pts=[];
    voxel_centers=[];
    num_voxel=160;
    s_voxel_deg=[]; 
    s_voxel_ndx=[];
    s_voxel_maxdegdiff=0;
    %%%%
    counts=[];
    r_max=[];
    g_max=[];
    r_means=[];
    g_means=[];
    
    r_vars=[];
    g_vars=[];
    %%%%%%%%%%%%%%%%%%%%%%%%
    save_str = struct;
    %%%%%%%%%%%%%%%%%%%%%%%%
    close all;clc;
    display_select_files();
    %display_cropping_figure;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function execute_CellProfiler()
        if(~isunix())
            fprintf('ERROR: CellProfiler integration not availiable\n');
            return;
        end
        %%%%
        cmd='';
        if(ismac())
            fid = fopen('/Applications/CellProfiler2.0.app/Contents/Resources/CellProfiler.py');
            if(fid~=-1)
                fclose(fid);
                setenv('RESOURCEPATH','/Applications/CellProfiler2.0.app/Contents/Resources/');
                setenv('PYTHONHOME','/Applications/CellProfiler2.0.app/Contents/Resources/');
                %setenv('PYTHONPATH','/Applications/CellProfiler2.0.app/Contents/Resources/lib/python2.5');
                %cmd = '/Applications/CellProfiler2.0.app/Contents/MacOS/python /Applications/CellProfiler2.0.app/Contents/Resources/CellProfiler.py';
                cmd = '/Applications/CellProfiler2.0.app/Contents/MacOS/python /Applications/CellProfiler2.0.app/Contents/Resources/__boot__.py';
            end
        end
        if(isempty(cmd))
            %TODO: make this work for different installations and OS's
            fprintf('Can not find CellProfiler\n');
            return;
        end
        %make option for user to select pipeline
        [FileName,PathName,FilterIndex] = uigetfile({'*.cp','CellProfiler Pipeline'},'Open CellProfiler Pipeline');
        if(FilterIndex>0)
            cp_pipeline_file=strcat(PathName,FileName);
            fprintf('Using CellProfiler pipeline %s\n',cp_pipeline_file);
        else
            fprintf('CellProfiler execution canceled\n');
            return;
        end
        %TODO: Make option for user to specify input/output dirs 
        input_dirs_are_tmp=1;  %set to zero to keep directories after execution
        %make tmpDir, save all image files there with regular name
        choice = questdlg('Use temporary files for CellProfiler, or specify your own',...
        'Use Temp files for CellProfiler?','Use temp','I will choose','Use temp');
        switch choice
            case 'Use temp'
                [foo,inputdir] =system('mktemp -t profile_cell.XXXXXXXXXX');          %#ok<*ASGLU>
                inputdir=strtrim(inputdir);%remove hidden chars
                delete(inputdir);
                mkdir(inputdir);
                [foo,outputdir] = system('mktemp -t profile_cell.XXXXXXXXXX');
                outputdir=strtrim(outputdir);%remove hidden chars
                delete(outputdir);
                mkdir(outputdir);
            case 'I will choose'
                inputdir = uigetdir('','Choose CellProfiler Input directory');
                outputdir = uigetdir('','Choose CellProfiler Output directory');
                input_dirs_are_tmp=0;
        end
        %user option to use Red,Green or both channels for CP
        choice = questdlg('Should we use the Green and/or Red channel with CellProfiler?', ...
    	'Choose Red or Green Channel', ...
        'Green Channel Only','Red Channel Only','Both Channels','Both Channels');
        switch choice
            case 'Green Channel Only'
                execute_CellProfiler__saveimages(inputdir,1);
            case 'Red Channel Only'
                execute_CellProfiler__saveimages(inputdir,2);
            case 'Both Channels'
                execute_CellProfiler__saveimages(inputdir,3);
        end
        %cp_pipeline_file = 'TESTER/edgefinder_PIPE.cp';
        %NOTE: make sure you pass in full paths for input/outputdir & cp_pipeline_file
        cmd=strcat(cmd,sprintf(' -c -r -p %s -i %s -o %s --measurements %s',...
            execute_CellProfiler__fullpath(cp_pipeline_file),...
            execute_CellProfiler__fullpath(inputdir),...
            execute_CellProfiler__fullpath(outputdir),...
            execute_CellProfiler__fullpath(strcat(outputdir,'/CPtoPC_data.mat'))));
        fprintf('%s\n',cmd);
        %%%%%%%%%%
        system(cmd);
        %%%%%%%%%%
        outlines=strcat(outputdir,'/%.3ioutline.tiff');
        bodies=strcat(outputdir,'/%.3ibody.tiff');
        actual=strcat(inputdir,'/%.3i.tiff');
        CP_data=strcat(outputdir,'/CPtoPC_data.mat');
        fprintf('[ref_CELLS, adj_x, adj_y ]= CPtoPC_3(''%s'',''%s'',''%s'',''%s'');\n',outlines,bodies,actual,CP_data);
        [ref_CELLS, adj_x, adj_y ]= CPtoPC_3(outlines,bodies,actual,CP_data);
        %Note: This is non-blocking, how do we fix that?
        %%%%%%%%%%
        if(input_dirs_are_tmp)
            %delete /tmp directories
            fprintf('deleting %s\n',outputdir);
            rmdir(outputdir,'s')
            fprintf('deleting %s\n',inputdir);
            rmdir(inputdir,'s')
        end
        %%%%%%%%%%
        keyboard
        error('THIS IS AS FAR AS I GOT');
    end%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function path=execute_CellProfiler__fullpath(file) %1=green,2=red,3=both
        [a b c]=fileparts(file);
        if(isempty(a))
            a=cd;
        else
            a=cd(cd(a));
        end
        path=fullfile(a,[b c]);
    end%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function execute_CellProfiler__saveimages(path,green_or_red) %1=green,2=red,3=both
        %A=load_cropped_data(cur_time);
        %imwrite(A,strcat(path,filename),'tif');
        for t=1:length(tspan);
            if(green_or_red==1)
                A = importdata(green_files{t});
            elseif(green_or_red==2)
                A = importdata(red_files{t});
            elseif(green_or_red==3)
                A = importdata(green_files{t})+importdata(red_files{t});
            else
                error('execute_CellProfiler__saveimages(): invalid green_or_red param');
            end
            filename = sprintf('/%.3i.tiff',t);
        	imwrite(A,strcat(path,filename),'tif');
            fprintf('wrote: %s\n',strcat(path,filename));
        end
    end%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function save_dataset(filename)
        s.tspan=tspan;
        s.green_files=green_files;
        s.red_files=red_files;
        s.cell_profile_data=cell_profile_data; 
        if(normalization_set)
            s.normalization_data = normalization_data;%#ok<STRNU>
        end
        save(filename,'-STRUCT','s');
        fprintf('Data Set saved as %s\n',filename);
    end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function display_select_files()
        fig=figure(1);clf;set(fig,'MenuBar','none');
        set(fig,'Position',[ get(0,'PointerLocation') 520 410]);
        display_select_files__draw();
    end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function display_select_files__draw()
        fig=figure(1);clf;set(fig,'MenuBar','none');
        pos = get(fig,'Position');
        %set(fig,'Position',[1500 1000 pos(3) pos(4)]);
        uicontrol(fig,'Style','pushbutton','String','Select Green Files','Position',[10 380 120 20],'Callback',@display_select_files__get_green);
        uicontrol(fig,'Style','pushbutton','String','Select Red Files','Position',[10 350 120 20],'Callback',@display_select_files__get_red);
        l = max( length(green_files),length(red_files));
        if(l==0)
        %    fprintf('l==0\n');
            uicontrol(fig,'Style','pushbutton','String','Load Data Set','Position',[10 320 90 20],'Callback',@display_select_files__loadset);
        %elseif(length(green_files)==length(red_files))
        else
            tspan=1:length(green_files);
        %    fprintf('length(green_files)==length(red_files)\n');
            if(isempty(dataset_savefile))
                uicontrol(fig,'Style','pushbutton','String','Save Data Set','Position',[10 320 90 20],'Callback',@display_select_files__saveset);
            else
                uicontrol(fig,'Style','pushbutton','String','Next','Position',[10 320 90 20],'Callback',@display_select_files__next);
                uicontrol(fig,'Style','pushbutton','String','Normalize','Position',[10 290 90 20],'Callback',@display_select_files__normalize);
            end
        %else
        %    fprintf('length(green_files)=%g\t=length(red_files)=%g\n',length(green_files),length(red_files));
        end
        %%%
        dat = cell(l,2);
        for i=1:length(green_files)
            dat{i,1}=green_files{i};
        end
        for i=1:length(red_files)
            dat{i,2}=red_files{i};
        end
        cnames = {'Green Files','Red Files'};
        %rnames = {'First','Second','Third'};
        uitable('Parent',fig,'Data',dat,'ColumnName',cnames,... %'RowName',rnames,...
            'Position',[160 10 pos(3)-160 pos(4)-20],'ColumnWidth',{(pos(3)-193)/2,(pos(3)-193)/2},...
            'CellSelectionCallback',@display_select_files__tablecellselected);
        %set(fig,'Units','pixels');
        pa = uipanel('Parent',fig,'Position',[.0025 .0025 .28 .4],...
            'BackgroundColor','white');
        p=axes('Parent',pa,'Position',[0 0 1 1]);
        setappdata(fig,'PanelHandle',p);
        %pt = uipanel('Parent',fig,'Position',[.005 .285 .28 .4],...
        %    'BackgroundColor','white');
        th = uicontrol(fig,'Style','text','String','Select file to preview','Position',[5 175 140 100]);
        setappdata(fig,'LabelHandle',th);
        drawnow;
    end%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function display_select_files__normalize(h,event)
        %ask to normalize per-channel, or global
        if(isempty(green_files)||isempty(red_files))
            choice='Separately';
        else
            choice = questdlg('Normalize channels separately or together',...
            'Normalize','Separately','Together','Together');
        end
        %find max/min values
        normalization_set=0;
        switch choice
            case 'Separately'
                top=0;
                bot=Inf;
                if(~isempty(green_files))
                for t=1:length(green_files)
                    a = double(importdata(green_files{t}));
                    at=max(max(a));
                    if(at>top),top=at;end
                    ab=min(min(a));
                    if(ab<bot),bot=ab;end
                    fprintf('%s : %g/%g\n',green_files{t},at,ab);
                end
                end
                normalization_data.green_bottom=bot;
                normalization_data.green_top=top-bot;
                top=0;
                bot=Inf;
                if(~isempty(red_files))
                for t=1:length(red_files)
                    a = double(importdata(red_files{t}));
                    at=max(max(a));
                    if(at>top),top=at;end
                    ab=min(min(a));
                    if(ab<bot),bot=ab;end
                    fprintf('%s : %g/%g\n',red_files{t},at,ab);
                end
                end
                normalization_data.red_bottom=bot;
                normalization_data.red_top=top-bot;
            case 'Together'
                top=0;
                bot=Inf;
                if(~isempty(green_files))
                for t=1:length(green_files)
                    fprintf('t=%g\n',t);
                    a = double(importdata(green_files{t}));
                    at=max(max(max(a)));
                    if(at>top),top=at;end
                    ab=min(min(min(a)));
                    if(ab<bot),bot=ab;end
                    fprintf('(%g) %s : %g/%g\n',t,green_files{t},at,ab);
                end
                end
                if(~isempty(red_files))
                for t=1:length(red_files)
                    a = double(importdata(red_files{t}));
                    at=max(max(max(a)));
                    if(at>top),top=at;end
                    ab=min(min(min(a)));
                    if(ab<bot),bot=ab;end
                    fprintf('%s : %g/%g\n',red_files{t},at,ab);
                end
                end
                normalization_data.green_bottom=bot;
                normalization_data.green_top=top-bot;
                normalization_data.red_bottom=bot;
                normalization_data.red_top=top-bot;
        end
        %fprintf('green normalizing top=%g bot=%g\n',normalization_data.green_top,normalization_data.green_bottom);
        %fprintf('red normalizing top=%g bot=%g\n',normalization_data.red_top,normalization_data.red_bottom);
        %set normalization constant
        normalization_set=1;
        %%%
        display_select_files__draw()
    end%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function display_select_files__next(h,event)
        display_cropping_figure();
    end%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function display_select_files__tablecellselected(h,event) %#ok<INUSL>
        if(~isempty(event.Indices))
            %fprintf('cell selected\n');
            tndx=event.Indices(end,1);
            gorr=event.Indices(end,2);
            if(gorr==1 && length(green_files)>=tndx && ~isempty(green_files{tndx}))
                p=getappdata(fig,'PanelHandle');
                th=getappdata(fig,'LabelHandle');
                image(load_data_green(tndx),'Parent',p);
                set(th,'String',green_files{tndx});
                %fprintf('drawing %s\n',green_files{tndx});
                drawnow;
            elseif(gorr==2 && length(red_files)>=tndx && ~isempty(red_files{tndx}))
                p=getappdata(fig,'PanelHandle');
                th=getappdata(fig,'LabelHandle');
                image(load_data_red(tndx),'Parent',p);
                set(th,'String',red_files{tndx});
                %fprintf('drawing %s\n',red_files{tndx});
                drawnow;
            end
        end
    end%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function display_select_files__saveset(h,event)
        fprintf('TODO\n');
        % find string common to all files
        common_string=display_select_files__saveset_getcommonstring();
        % open save dialog: suggest 'common_string'-dataset.mat
        [filename,path,filterindex] = uiputfile({'*-dataset.mat';'*.mat'},'Save Data Set',strcat(common_string,'-dataset.mat'));
        if(filterindex>0)
            % save dataset
            dataset_savefile=strcat(path,filename);
            save_dataset(dataset_savefile);
        end
        display_select_files__draw();
    end%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function common_string=display_select_files__saveset_getcommonstring()
        l=length(green_files);
        %%%
        [pn,fn,ext]=fileparts(green_files{1}); %#ok<NASGU>
        common_string=fn;
        for rg=1:2
        for i=rg:l
            if(rg==1)
                if(isempty(red_files)),break;end
                cmp_str=red_files{i};
            else
                if(isempty(green_files)),break;end
                cmp_str=green_files{i};
            end
            [pn,fn,ext]=fileparts(cmp_str); %#ok<NASGU>
            cmp_str=fn;
            fprintf('\t%s vs %s\n',common_string,cmp_str);
            sl=min(length(common_string),length(cmp_str));
            eql=cmp_str(1:sl)==common_string(1:sl);
            for j=1:sl
                if(eql(j)==0)
                    common_string(j)='_';
                end
            end
            if(length(common_string)>sl)
                for j=sl:length(common_string)
                    common_string(j)='_';
                end
            elseif(length(common_string)<length(cmp_str))
                for j=length(common_string):length(cmp_str)
                    common_string(j)='_';
                end
            end
        end
        end
        %%%
        %%%
        %if( length(common_string)>3 && strcmp(common_string(end-3:end),'.tif'))
        %    common_string=common_string(end-4:end);
        %elseif( length(common_string)>4 && strcmp(common_string(end-4:end),'.tiff'))
        %    common_string=common_string(1:end-5);
        %end
        %%%
        is_all_under=1;
        for i=1:length(common_string)
            if(common_string(i)~='_')
                is_all_under=0;
                break;
            end
        end
        %%%
        if(isempty(common_string) || is_all_under )
            common_string=strcat('profilecell_',date());
        end
    end%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function display_select_files__loadset(h,event)
        fprintf('Loading Data Set\n');
        [FileName,PathName,FilterIndex] = uigetfile({'*-dataset*.mat','Profile Cell Data Set';...
                                                    '*.mat','Matlab data file'},'Load Data Set');
        if(FilterIndex>0)
            dataset_savefile=strcat(PathName,FileName);
            s=load(dataset_savefile);
            if(isfield(s,'green_files')&& ~isempty(s.green_files)),green_files = display_select_files__loadset__validate_files(s.green_files,PathName);end
            if(isfield(s,'red_files') && ~isempty(s.red_files)),red_files=display_select_files__loadset__validate_files(s.red_files,PathName);end
            if(isfield(s,'tspan')),tspan=s.tspan;end
            if(isfield(s,'cell_profile_data')),cell_profile_data=s.cell_profile_data;end
            if(isfield(s,'normalization_data')),normalization_data=s.normalization_data;normalization_set=1;end
            fprintf('Data Set %s loaded\n',dataset_savefile);
            %%%%%%%%%%%%%%%%%%%%
        end
        display_select_files__draw();
    end%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function outfiles = display_select_files__loadset__validate_files(infiles,dataset_path)
        for i=1:length(infiles)
            fid=fopen(infiles{i});  %try in location specified
            if(fid~=-1)
                fclose(fid);
                outfiles{i}=infiles{i}; %#ok<*AGROW>
            else
                [path,name,ext]=fileparts(infiles{i});
                fname=strcat(dataset_path,filesep,name,ext);
                fid=fopen(fname); %try in same dir as dataset
                if(fid~=-1)
                    fclose(fid);
                    outfiles{i}=fname;
                else
                    fname=strcat(pwd(),filesep,name,ext);
                    fid=fopen(fname); %try in same dir as dataset
                    if(fid~=-1)
                        fclose(fid);
                        outfiles{i}=fname;
                    else
                        error('Can not file file in dataset, file=%s, also checked in %s and %s',infiles{i},datatset_path,pwd());
                    end
                end
            end
        end
    end%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function display_select_files__get_red(h,event)
        [FileName,PathName,FilterIndex] = uigetfile('*.tif;*.tiff','Select Files in Red Channel','MultiSelect', 'on');
        if(FilterIndex>0)
            r=strcat(PathName,FileName);
            red_files={};
            if(iscell(r))
                for i=1:length(r)
                    red_files{i}=r{i};
                %    fprintf('\t%s\n',red_files{i});
                end
            else
                red_files{1}=r;
            end
        end
        display_select_files__draw();
    end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function display_select_files__get_green(h,event)
        [FileName,PathName,FilterIndex] = uigetfile('*.tif;*.tiff','Select Files in Green Channel','MultiSelect', 'on');
        if(FilterIndex>0)
            g=strcat(PathName,FileName);
            %fprintf('length(g)=%g\n',length(g));
            %fprintf('iscell(g)=%g\n',iscell(g));
            green_files={};
            if(iscell(g))
                for i=1:length(g)
                    green_files{i}=g{i};
                %    fprintf('\t%s\n',green_files{i});
                end
            else
                green_files{1}=g;
            end
        end
        display_select_files__draw();
    end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function analyse_data__savealldata(h,event)
        %uisave({'save_str'},'cell_analysis_all.mat');
        [filename,path,filterindex] = uiputfile('*.mat','Save Data',sprintf('cell_analysis_all-cell%g.mat',current_cell_selected));
        if(filterindex>0)
            save(strcat(path,filename),'-struct','save_str');
            fprintf('data saved to "%s"\n',strcat(path,filename));
        end
    end
    function analyse_data__savedata(h,event)
        uisave({'counts','r_max','g_max','r_means','g_means','r_vars','g_vars',...
            's_voxel_deg','s_voxel_ndx','cur_time'},sprintf('cell_analysis-cell%g-t%g.mat',current_cell_selected,cur_time));
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function display_masking_figure__exec_analysis_pipeline(h,evt)
        save_str.counts=[];
        save_str.r_max=[];
        save_str.g_max=[];
        save_str.r_means=[];
        save_str.g_means=[];
        save_str.r_vars=[];
        save_str.g_vars=[];
        save_str.times=[];
        save_str.voxel_deg=[];
        for i=1:length(tspan)
            %%%%
            analyse_data__do(tspan(i))
            %%%%
            save_str.counts(:,i)=counts(s_voxel_ndx);
            save_str.r_max(:,i)=r_max(s_voxel_ndx);
            save_str.g_max(:,i)=g_max(s_voxel_ndx);
            save_str.r_means(:,i)=r_means(s_voxel_ndx);
            save_str.g_means(:,i)=g_means(s_voxel_ndx);
            save_str.r_vars(:,i)=r_vars(s_voxel_ndx);
            save_str.g_vars(:,i)=g_vars(s_voxel_ndx);
            save_str.times(i)=tspan(i);
            if(i==1)
                save_str.voxel_deg=s_voxel_deg;
            end
        end
        %%%
        close all;
        save_var = analysis_pipeline(save_str.g_max,save_str.r_max,save_str.times,save_str.voxel_deg);
        %TODO: some way to come back to the app
        while(1)
            choice = menu('Profile_Cell',...
            'Plot','Save Data','Home','Quit');
            pause(.5); %don't ask me why I have to do this, but it won't work otherwise.
            switch choice
                case 1
                    analysis_pipeline_plot(save_var);
                case 2
                    display_masking_figure__exec_analysis_pipeline_save(save_var);
                case 3
                    close all;
                    display_cropping_figure();
                    return;
                case 4
                    close all;
                    return;
            end
        end
        %%%
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function display_masking_figure__exec_analysis_pipeline_save(save_var)
        [filename,path,filterindex] = uiputfile('*.mat','Save Data',sprintf('analysis_pipeline-cell%g.mat',current_cell_selected));
        if(filterindex>0)
            save(strcat(path,filename),'-struct','save_var');
            fprintf('analysis saved to "%s"\n',strcat(path,filename));
        end
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function analyse_all_data()
        save_str.counts=[];
        save_str.r_max=[];
        save_str.g_max=[];
        save_str.r_means=[];
        save_str.g_means=[];
        save_str.r_vars=[];
        save_str.g_vars=[];
        save_str.times=[];
        save_str.voxel_deg=[];
        for i=1:length(tspan)
            %%%%
            analyse_data__do(tspan(i))
            %%%%
            save_str.counts(:,i)=counts(s_voxel_ndx);
            save_str.r_max(:,i)=r_max(s_voxel_ndx);
            save_str.g_max(:,i)=g_max(s_voxel_ndx);
            save_str.r_means(:,i)=r_means(s_voxel_ndx);
            save_str.g_means(:,i)=g_means(s_voxel_ndx);
            save_str.r_vars(:,i)=r_vars(s_voxel_ndx);
            save_str.g_vars(:,i)=g_vars(s_voxel_ndx);
            save_str.times(i)=tspan(i);
            if(i==1)
                save_str.voxel_deg=s_voxel_deg;
            end
            %pause(.1);
        end
        fig=figure(3);clf;
        surf(save_str.times,save_str.voxel_deg,save_str.r_max);
        title('Red Max');xlabel('time');ylabel('space');
        uicontrol(fig,'Style','pushbutton','String','Save Data','Position',[2 25 70 20],'Callback',@analyse_data__savealldata);
        uicontrol(fig,'Style','pushbutton','String','Close','Position',[2 5 70 20],'Callback','close');        
        fig=figure(4);clf;
        surf(save_str.times,save_str.voxel_deg,save_str.g_max);
        title('Green Max');xlabel('time');ylabel('space');
        uicontrol(fig,'Style','pushbutton','String','Save Data','Position',[2 25 70 20],'Callback',@analyse_data__savealldata);
        uicontrol(fig,'Style','pushbutton','String','Close','Position',[2 5 70 20],'Callback','close');        
    end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function analyse_data()
        analyse_data__do(cur_time);
        analyse_data__plot();
    end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function analyse_data__do(t)
        data=load_cropped_data(t);
        flag = uint8(zeros(size(data)));
        [mx my mz]=size(data);                                  %#ok<NASGU>
        for i=1:length(edgepts)
            x=ceil(edgepts(i,2));
            y=ceil(edgepts(i,1));
            flag(x,y,:)=1;
            if(x-1>0&&y-1>0),flag(x-1,y-1,:)=1;end  %nw
            if(x-1>0&&y>0),flag(x-1,y,:)=1;end  %n
            if(x-1>0&&y+1<=my),flag(x-1,y+1,:)=1;end %ne
            %if(x+1<=mx&&y-1>0),flag(x+1,y-1,:)=1;end %sw
            if(x+1<=mx&&y>0),flag(x+1,y,:)=1;end %s
            %if(x+1<=mx&&y-1<=my),flag(x+1,y-1,:)=1;end %se
            if(x>0&&y-1>0),flag(x,y-1,:)=1;end %w
            if(x>0&&y+1<=my),flag(x,y+1,:)=1;end %e
            %if(x-2>0&&y-1>0),flag(x-2,y-1,:)=1;end  %nnw
            if(x-2>0&&y>0),flag(x-2,y,:)=1;end  %nn
            %if(x-2>0&&y+1<=my),flag(x-2,y+1,:)=1;end %nne
        end
        fig=figure(2);clf;hold off
        image(data.*flag);axis image;
        title(sprintf('pixels used to for data analysis, t=%g',t));
        %%%
        counts = zeros(num_voxel,1);
        r_max = zeros(num_voxel,1);
        g_max = zeros(num_voxel,1);
        r_sums = zeros(num_voxel,1);
        g_sums = zeros(num_voxel,1);
        r_ssums = zeros(num_voxel,1);
        g_ssums = zeros(num_voxel,1);
        %data_vox = uint8(zeros(size(data)));
        deg_vals=[];
        for i=1:mx
            for j=1:my
                if(flag(i,j,1)==1)
                    %deg = find_pixel_deg(i,j);
                    deg = find_pixel_deg(j,i);
                    if(isempty(deg_vals))
                       deg_vals(1)=deg; 
                    else
                       deg_vals(end+1)=deg; %#ok<AGROW>
                    end
                    %vn = find_voxel_num(i,j);
                    vn = find_voxel_num(j,i);
                    %hold on
                    %plot([j-.5 voxel_centers(vn,1)],[i-.5 voxel_centers(vn,2)],'-r');
                    %plot([voxel_centers(vn,1)],[voxel_centers(vn,2)],'xb');
                    %hold off
                    %drawnow;
                    %pause(.1)
                    %data_vox(i,j,:) = uint8(ceil(vn/voxel*255));
                    counts(vn)=counts(vn)+1;
                    r_sums(vn)=r_sums(vn)+data(i,j,1);
                    g_sums(vn)=g_sums(vn)+data(i,j,2);
                    r_ssums(vn)=r_ssums(vn)+data(i,j,1)^2;
                    g_ssums(vn)=g_ssums(vn)+data(i,j,2)^2;
                    r_max(vn) = max( r_max(vn) , data(i,j,1));
                    g_max(vn) = max( g_max(vn) , data(i,j,2));
                end
            end
        end
        r_means = r_sums./counts;
        g_means = g_sums./counts;
        r_vars = r_ssums./counts - r_means.^2;
        g_vars = g_ssums./counts - g_means.^2;
        % make sure every voxel has a value
         for v=1:num_voxel
             if(counts(v)==0)
                 fprintf('voxel %g has zero values\n',v);
%                 if(v>1 && counts(v-1)~=0)
%                     counts(v)=1;
%                     r_max(v)=r_max(v-1);
%                     g_max(v)=g_max(v-1);
%                     r_means(v)=r_means(v-1);
%                     g_means(v)=g_means(v-1);
%                     r_vars(v)=r_vars(v-1);
%                     g_vars(v)=g_vars(v-1);
%                 elseif(v==1 && counts(end)~=0)
%                     counts(v)=1;
%                     r_max(v)=r_max(end);
%                     g_max(v)=g_max(end);
%                     r_means(v)=r_means(end);
%                     g_means(v)=g_means(end);
%                     r_vars(v)=r_vars(end);
%                     g_vars(v)=g_vars(end);
%                 end
%                 if(v<num_voxel && counts(v+1)~=0)
%                     counts(v)=counts(v)+1;
%                     r_max(v)=r_max(v)+r_max(v+1);
%                     g_max(v)=g_max(v)+g_max(v+1);
%                     r_means(v)=r_means(v)+r_means(v+1);
%                     g_means(v)=g_means(v)+g_means(v+1);
%                     r_vars(v)=r_vars(v)+r_vars(v+1);
%                     g_vars(v)=g_vars(v)+g_vars(v+1);
%                 elseif(v==num_voxel && counts(1)~=0)
%                     counts(v)=counts(v)+1;
%                     r_max(v)=r_max(v)+r_max(1);
%                     g_max(v)=g_max(v)+g_max(1);
%                     r_means(v)=r_means(v)+r_means(1);
%                     g_means(v)=g_means(v)+g_means(1);
%                     r_vars(v)=r_vars(v)+r_vars(1);
%                     g_vars(v)=g_vars(v)+g_vars(1);
%                 end
%                 counts(v)=counts(v)/2;
%                 r_max(v)=r_max(v)/counts(v);
%                 g_max(v)=g_max(v)/counts(v);
%                 r_means(v)=r_means(v)/counts(v);
%                 g_means(v)=g_means(v)/counts(v);
%                 r_vars(v)=r_vars(v)/counts(v);
%                 g_vars(v)=g_vars(v)/counts(v);
             end
         end
    end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function analyse_data__plot()
        degs = s_voxel_deg;
        %figure(3);clf;
        %subplot(2,1,1);errorbar(degs,r_means(s_voxel_ndx),sqrt(r_vars(s_voxel_ndx)));title('Red mean/std');
        %subplot(2,1,2);errorbar(degs,g_means(s_voxel_ndx),sqrt(g_vars(s_voxel_ndx)));title('Green mean/std');
        %figure(4);clf;
        %s_voxel_deg=[]; 
        %s_voxel_ndx=[];
        %subplot(2,1,1);plot(degs,r_means(s_voxel_ndx));title('Red mean');axis([0 360 min(r_means) max(r_means)]);
        %subplot(2,1,2);plot(degs,g_means(s_voxel_ndx));title('Green mean');axis([0 360 min(g_means) max(g_means)]);
        if(~isempty(green_files)&&~isempty(red_files))
            fig=figure(3);clf;
            subplot(2,1,1);plot(degs,r_max(s_voxel_ndx),'-b',degs,r_means(s_voxel_ndx),'-r');title('Red max/mean');axis([0 360 min(r_max) max(r_max)]);
            subplot(2,1,2);plot(degs,g_max(s_voxel_ndx),'-b',degs,g_means(s_voxel_ndx),'-r');title('Green max/mean');axis([0 360 min(g_max) max(g_max)]);
        elseif(~isempty(green_files))
            fig=figure(3);clf;
            plot(degs,g_max(s_voxel_ndx),'-b',degs,g_means(s_voxel_ndx),'-r');title('Green max/mean');axis([0 360 min(g_max) max(g_max)]);
        elseif(~isempty(red_files))
            fig=figure(3);clf;
            plot(degs,r_max(s_voxel_ndx),'-b',degs,r_means(s_voxel_ndx),'-r');title('Red max/mean');axis([0 360 min(r_max) max(r_max)]);
        else
            fprintf('red and green files empty');
        end
        uicontrol(fig,'Style','pushbutton','String','Save Data','Position',[2 25 70 20],'Callback',@analyse_data__savedata);
        uicontrol(fig,'Style','pushbutton','String','Close','Position',[2 5 70 20],'Callback','close');        
        %figure(5);clf;
        %plot(counts);title('pixels per voxel')
    end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function deg = find_pixel_deg(x,y)
        %plot(cpt(1),cpt(2),'xw','LineWidth',2);
        ycoord = (y-cpt(2));
        xcoord = (x-cpt(1));
        deg = atand(abs(xcoord)/abs(ycoord));
        if(xcoord>=0 && ycoord>0) % 2nd quad
            deg = (90-deg)+90;
        elseif(xcoord>=0 && ycoord<=0) %1st quad
            deg = deg;  %#ok<ASGSL> %seems backwards, but works now
        elseif(xcoord<0 && ycoord>0) %3rd quad
            deg = 180+deg;
        elseif(xcoord<0 && ycoord<=0) %4th quad
            deg = 360-deg;
        else
            deg=0;
        end
        if(isnan(deg)),deg=0;end
    end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function ndx = find_voxel_num(x,y)
        %deg = find_pixel_deg(x,y);
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %ndx = floor(deg*(num_voxel/360))+1;
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %TODO: fix so that it finds the closest voxel center
        %s_voxel_deg=[]; 
        %s_voxel_ndx=[];
        %s_voxel_maxdegdiff=0;
        %fprintf('\nfind_pixel_deg(%g,%g)=%g deg\n',x,y,deg);
%         if(deg-s_voxel_maxdegdiff >0)
%             dndx1=find(s_voxel_deg>=(deg-s_voxel_maxdegdiff),1,'first');
%             %fprintf('\tlower bound (%g, %g deg)\n',dndx1,(deg-s_voxel_maxdegdiff))
%         else
%             dndx1=find(s_voxel_deg<(360-deg-s_voxel_maxdegdiff),1,'last');
%             %fprintf('\tlower bound (%g, %g deg)\n',dndx1,(360-deg-s_voxel_maxdegdiff))
%         end
%         if(deg+s_voxel_maxdegdiff>360)
%             dndx2=find(s_voxel_deg>(deg+s_voxel_maxdegdiff-360),1,'first');
%             %fprintf('\tupper bound (%g, %g deg)\n',dndx2,(deg+s_voxel_maxdegdiff-360))
%             %    fprintf('\t%g %g %g\n',s_voxel_deg(end),s_voxel_deg(1),s_voxel_maxdegdiff);
%         else
%             dndx2=find(s_voxel_deg<=(deg+s_voxel_maxdegdiff),1,'last');
%             %fprintf('\tupper bound (%g, %g deg)\n',dndx2,(deg+s_voxel_maxdegdiff))
%             %    fprintf('\t%g %g %g\n',s_voxel_deg(end),s_voxel_deg(1),s_voxel_maxdegdiff);
%         end
%         if(dndx1>dndx2)
%             len_vndx=length(s_voxel_ndx);
%             vndx=circshift(s_voxel_ndx,(len_vndx-dndx1+dndx2));
%             dndx2=len_vndx-dndx1+dndx2;
%             dndx1=1;
%             vndx = vndx(dndx1:dndx2);
%         else
%             vndx=s_voxel_ndx(dndx1:dndx2);
%         end
        vndx=s_voxel_ndx;
        ndx=-1;
        min_vox_dist=-1;
        %fprintf('length(vndx)=%g  dndx1=%g  dndx2=%g\n',length(vndx),dndx1,dndx2);
        for i=1:length(vndx)
            %fprintf('\t%i checking v=%i (ndx=%g, min=%g)\n',i,vndx(i),ndx,min_vox_dist)
            vox_dist = dist_between_two_pts([voxel_centers(vndx(i),:) ;[x-.5 y-.5] ]);
            if(min_vox_dist==-1 || vox_dist < min_vox_dist)
                min_vox_dist=vox_dist;
                ndx=vndx(i);
            end
        end
        %fprintf('ndx=%g, min=%g\n',ndx,min_vox_dist)
        %fprintf('find_voxel_num(%g,%g)=[%g,%g deg]\n',x,y,ndx,deg);
        if(ndx==-1),error('could not find voxel');end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function data_out = load_data(t)                           %#ok<*DEFNU>
        green_out = load_data_green(t);
        gsz=size(green_out);
        red_out = load_data_red(t);
        rsz=size(red_out);
        if(sum(size(green_out))>0 && sum(size(red_out))>0)
            if(rsz(1)~=gsz(1) || rsz(2)~=gsz(2))
                error('Red and green channels have differing number of pixels');
            end
            data_out=red_out+green_out;
        elseif(sum(size(green_out))>0)
            data_out = green_out; %#ok<NASGU>
        elseif(sum(size(red_out))>0)
            data_out = red_out; %#ok<NASGU>
        else
            error('Both Red and Green channels are empty');
        end
% a = importdata('1-2.tif');
% a=double(a);
% a=a-min(min(a));
% a=a/max(max(a))*255;
% A(:,:,2)=uint8(a);
% figure(1);image(A);
%        sz=size(data_out);
%        fprintf('load_data = [%g %g]\n',sz(1),sz(2));
    end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function data_out = load_data_green(t)                     %#ok<*DEFNU>
        data_out=[];
        if(length(green_files)>=t)
            a = double(importdata(green_files{t}));
            if(normalization_set==1)
                %fprintf('normalizing top=%g bot=%g\n',normalization_data.green_top,normalization_data.green_bottom);
                a=(a-normalization_data.green_bottom)/normalization_data.green_top*255;
            end
            if(isa(a,'uint16'))
                a=double(a)/65535*255;
            end
            gsz=size(a);
            data_out=uint8(zeros(gsz(1),gsz(2),3));
            if(length(gsz)==3 && gsz(3)==3)
                data_out(:,:,:)= uint8(double(a));
            elseif(length(gsz)==2 || gsz(3)==1)
                data_out(:,:,2)= uint8(double(a));
            else
                error('Can not read file: %s',green_files{t});
            end
        end
    end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function data_out = load_data_red(t)                       %#ok<*DEFNU>
        data_out=[];
        if(length(red_files)>=t)
            a = double(importdata(red_files{t}));
            if(normalization_set==1)
                %fprintf('normalizing top=%g bot=%g\n',normalization_data.red_top,normalization_data.red_bottom);
                a=(a-normalization_data.red_bottom)/normalization_data.red_top*255;
            end
            rsz=size(a);
            data_out=uint8(zeros(rsz(1),rsz(2),3));
            if(length(rsz)==3 && rsz(3)==3)
                data_out(:,:,:)= uint8(double(a));
            elseif(length(rsz)==2 || rsz(3)==1)
                data_out(:,:,1)= uint8(double(a));
            else
                error('Can not read file: %s',red_files{t});
            end
        end
    end% function load_data
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function data_out = load_cropped_data(t)
        data_full = load_data(t);
        %[top bottom left right]=crop_lim{t};
        lim=crop_lim{t};
        sz=size(data_full);
        data_out = data_full(max(1,lim(1)):min(lim(2),sz(1)),max(1,lim(3)):min(lim(4),sz(2)),:);
%         fprintf('data_out = zeros(%g,%g,3)\n',lim(2)-lim(1)+1,lim(4)-lim(3)+1);
%         data_out = uint8(zeros(lim(2)-lim(1)+1,lim(4)-lim(3)+1,3));
%         fprintf('data_full(%g:%g,%g:%g,:)\n',max(1,lim(1)),min(lim(2),sz(1)),max(1,lim(3)),min(lim(4),sz(2)));
%         data_full=data_full(max(1,lim(1)):min(lim(2),sz(1)),max(1,lim(3)):min(lim(4),sz(2)),:);
%         sz2=size(data_out);
%         fprintf('data_out(%g:%g,%g:%g,:)=data_full;\n',max(1,1-lim(1)),min(sz2(1)-sz(1)-lim(2),sz2(1)),...
%             max(1,1-lim(3)),min(sz2(2)-sz(2)-lim(4)));
%         data_out(max(1,1-lim(1)):min(sz2(1)-sz(1)-lim(2),sz2(1)),...
%             max(1,1-lim(3)):min(sz2(2)-sz(2)-lim(4),sz2(2)) ,:)=data_full;
    end% function load_data
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function curve_edge_points()
        fig=figure(1);clf;set(fig,'MenuBar','none');%set(fig,'Position',[ get(0,'PointerLocation') 520 410]);
        image(load_cropped_data(cur_time));axis image;
        %title('Click on a location to start the curve');
        %[x y] = ginput(1);
        x=0;y=0;
        %hold on
        %plot(x,y,'or','LineWidth',2);
        %hold off
        deg = find_pixel_deg(x,y);
        %title('Click again');
        %[x2 y2] = ginput(1);
        %hold on
        %plot(x2,y2,'xr','LineWidth',2);
        %hold off
        %deg2=find_pixel_deg(x2,y2);
        %%%%%%%%%%%%%%%
        rad=sqrt((x-cpt(1))^2 + (y-cpt(2))^2);
        %rad2=sqrt((x2-cpt(1))^2 + (y2-cpt(2))^2);
        %fprintf('%g=sqrt((%g-%g)^2 + (%g-%g)^2);\n',rad,x,cpt(1),y,cpt(2));
        fprintf('starting at deg=%g r=%g\n',deg,rad);
        %fprintf('to at deg=%g r=%g\n',deg2,rad2);
        %%%%%%%%%%%%%%%
        ptsdegs = zeros(length(edgepts),1);
        ptsradius = zeros(length(edgepts),1);
        for i=1:length(edgepts)
            ptsdegs(i)=find_pixel_deg(edgepts(i,1),edgepts(i,2));
            ptsradius(i)=sqrt((edgepts(i,1)-cpt(1))^2 + (edgepts(i,2)-cpt(2))^2);
        end
        [sptsdegs, ndx]=sort(ptsdegs);
        %figure(2);clf;
        %plot(ptsdegs(ndx),ptsradius(ndx),'-');title('radius vs deg')
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        curve_pts_deg_dist=2;
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        curve_pts=[];
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        for itr=1:(360/curve_pts_deg_dist);
            %%%%
            [newx newy] = curve_edge_points_next(deg,sptsdegs, ndx,ptsdegs,ptsradius);
            fprintf('\tdeg=%g  (%g,%g)\n',deg,newx,newy);
            if(isempty(curve_pts))
                curve_pts(1,:)=[newx newy];
            else
                curve_pts(end+1,:)=[newx newy]; %#ok<AGROW>
            end
            %%%%
            hold on
            plot(newx,newy,'.w','LineWidth',2);
            hold off
            deg = deg + curve_pts_deg_dist;
            if(deg>360),deg=deg-360;end
            %break;
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        curve_pts = sort_points(curve_pts);
        pt_dist = dist_between_pts(curve_pts);
        mean_pts_dist = mean(pt_dist);
        loopcntr=0;
        while( max(pt_dist) > 1.1*mean_pts_dist)
            loopcntr=loopcntr+1;if(loopcntr>200),error('runaway loop');end
            n1=find(pt_dist==max(pt_dist),1,'first');
            if(n1<=0),error('n1<=0');end
            if(isempty(n1)),error('empty(n1);');end
            if(n1==1)
                qx = mean([ curve_pts(end,1) curve_pts(1,1)]);
                qy = mean([ curve_pts(end,2) curve_pts(1,2)]);
            else
                %fprintf('\t(%g,%g) :: ((%g,%g) :: %g - %g\n',...
                %    curve_pts(n1-1,1),curve_pts(n1-1,2),curve_pts(n1,1),curve_pts(n1,2),...
                %    find_pixel_deg(curve_pts(n1-1,1),curve_pts(n1-1,2)),...
                %    find_pixel_deg(curve_pts(n1,1),curve_pts(n1,2)));
                qx = mean([ curve_pts(n1-1,1) curve_pts(n1,1)]);
                qy = mean([ curve_pts(n1-1,2) curve_pts(n1,2)]);
            end
            deg = find_pixel_deg(qx,qy);
            fprintf('interpolating: deg=%g  (%g,%g) n1=%g\n',deg,qx,qy,n1);
            %[newx newy] = curve_edge_points_intrp(deg,sptsdegs, ndx,ptsdegs,ptsradius);
            curve_pts(end+1,:)=[qx qy];                     %#ok<AGROW>
            curve_pts = sort_points(curve_pts);
            %%%
            pt_dist = dist_between_pts(curve_pts);
            if(min(pt_dist)==0)
                error('min(pt_dist)==0');
            end
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % calculate voxel centers
        fprintf('total circumferential distance=%g\n',sum(pt_dist));
        dist_per_voxel = sum(pt_dist)/num_voxel;
        fprintf('dist_per_voxel=%g\n',dist_per_voxel);
        voxel_centers=zeros(num_voxel,2);
        voxel_centers(1,:) = curve_pts(end,:);
        fprintf('vox %g (%g %g)\n',1,curve_pts(end,1),curve_pts(end,2));
        ci=1; cilen=length(curve_pts); lci=cilen;
        for v=2:num_voxel
            dist_to_go = dist_per_voxel;
            dist_left = dist_between_two_pts([voxel_centers(v-1,:) ;curve_pts(ci,:) ]);
            %fprintf('to_go=%g left=%g ci=%g lci=%g\n',dist_to_go,dist_left,ci,lci);
            if(dist_left<=dist_to_go)
                dist_to_go =dist_to_go - dist_left;
                lci=ci;ci=ci+1;
                %fprintf('\tto_go=%g ci=%g lci=%g\n',dist_to_go,ci,lci);
                while(dist_to_go > pt_dist(ci))
                    dist_to_go = dist_to_go - pt_dist(ci);
                    lci=ci;ci=ci+1;
                    %fprintf('\tto_go=%g ci=%g lci=%g\n',dist_to_go,ci,lci);
                end
            end
            ratio= dist_to_go/dist_between_two_pts([curve_pts(lci,:) ;curve_pts(ci,:) ]);
            dx=curve_pts(ci,1)-curve_pts(lci,1);
            dy=curve_pts(ci,2)-curve_pts(lci,2);
            voxel_centers(v,1) = curve_pts(lci,1)+ratio*dx;
            voxel_centers(v,2) = curve_pts(lci,2)+ratio*dy;
            fprintf('vox %g (%g %g)\n',v,dx,dy);
            between = dist_between_two_pts([voxel_centers(v-1,:) ;voxel_centers(v,:) ]);
            %fprintf('\t they are %g distant\n',between);
            if(between<dist_per_voxel/2)
                error('error! voxels are too close\n');
            end
            %if(v>3), break,end
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        voxel_degs = zeros(length(voxel_centers),1);
        hold on
        for v=1:num_voxel
            plot(voxel_centers(v,1),voxel_centers(v,2),'xr');
            voxel_degs(v) = find_pixel_deg(voxel_centers(v,1),voxel_centers(v,2));
        end
        [s_voxel_deg s_voxel_ndx] = sort(voxel_degs);
        %fprintf('size(voxel_degs) ');
        %size(voxel_degs)
        %fprintf('size(s_voxel_deg) ');
        %size(s_voxel_deg)
        %fprintf('size(diff(s_voxel_deg)) ');
        %size(diff(s_voxel_deg))
        s_voxel_maxdegdiff= max([2 min(diff(s_voxel_deg))]); %#ok<SETNU>
        hold off
        %fig=figure(2);
        title('Data ready to be analyized');
        if(exist('analysis_pipeline')) %#ok<*EXIST>
            uicontrol(fig,'Style','pushbutton','String','Analysis Pipeline','Position',[10 120 120 20],'Callback',@display_masking_figure__exec_analysis_pipeline);
        end
        uicontrol(fig,'Style','pushbutton','String','Analyze','Position',[20 90 70 20],'Callback',@display_masking_figure__analyze);
        uicontrol(fig,'Style','pushbutton','String','Analyze All','Position',[15 60 80 20],'Callback',@display_masking_figure__analyzeall);
        uicontrol(fig,'Style','pushbutton','String','Back','Position',[20 30 70 20],'Callback',@curve_edge_points__done);
    end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function curve_edge_points__done(h,evt)
        close all;
        %display_cropping_figure();
        display_masking_figure__draw();
    end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function deg = angle_between_pts(pt1,pt2)
        ycoord = (pt2(2)-pt1(2));
        xcoord = (pt2(1)-pt1(2));
        deg = atand(abs(xcoord)/abs(ycoord));
        if(xcoord>=0 && ycoord>0) % 2nd quad
            deg = (90-deg)+90;
        elseif(xcoord>=0 && ycoord<=0) %1st quad
            deg = deg;  %#ok<ASGSL> %seems backwards, but works now
        elseif(xcoord<0 && ycoord>0) %3rd quad
            deg = 180+deg;
        elseif(xcoord<0 && ycoord<=0) %4th quad
            deg = 360-deg;
        else
            deg=0;
        end
        if(isnan(deg)),deg=0;end
    end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function degs = sort_points_deg(upts)
        len=length(upts);
        %fprintf('len=%g\n',len);disp(size(upts));
        for i=1:len
            degs(i)=find_pixel_deg( upts(i,1) , upts(i,2) ); %#ok<AGROW>
        end
    end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function spts = sort_points(upts)
        degs = sort_points_deg(upts);
        [tmp, ndx]=sort(degs);
        spts=upts(ndx,:);
    end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function dist = dist_between_two_pts(ipts)
        dist = sqrt( (ipts(1,1)-ipts(2,1))^2 + (ipts(1,2)-ipts(2,2))^2 );
    end
    function dist = dist_between_pts(ipts)
        len = length(ipts);
        dist=zeros(len,1);
        i=1;j=len;
        dist(1) = sqrt( (ipts(i,1)-ipts(j,1))^2 + (ipts(i,2)-ipts(j,2))^2 );
        for i=2:len
            j=i-1;
            dist(i) = sqrt( (ipts(i,1)-ipts(j,1))^2 + (ipts(i,2)-ipts(j,2))^2 );
            if(dist(i)==0)
                fprintf('sqrt( (%g-%g)^2 + (%g-%g)^2 )=%g\n',ipts(i,1),ipts(j,1),ipts(i,2),ipts(j,2),dist(i));
            end
        end
    end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function [newx newy] = curve_edge_points_next(deg,sptsdegs,ndx,ptsdegs,ptsradius)
    %function [newy newx] = curve_edge_points_next(deg,sptsdegs,ndx,ptsdegs,ptsradius)
        %fprintf('curve_edge_points_next(%g...\n',deg);
        %%%
        delta_deg=5;
        %%%
        n1=find(sptsdegs>deg,1,'first');
        d2 = deg+delta_deg;
        %fprintf('\tn1=%g\n',n1);
        if(isempty(n1)),n1=0;end
        if(d2>360)
            d2=d2-360;
            if(n1==0)
                n2=find(sptsdegs>d2,1,'first');
            else
                n2=find(sptsdegs>d2,1,'first')+(length(sptsdegs)-n1);
            end
        else
            n2=find(sptsdegs>d2,1,'first')-n1;
        end
        d3=deg-delta_deg;
        if(d3<0)
            d3=d3+360;
            %fprintf('(%g-%g)+%g  (d3=%g)\n',length(sptsdegs),find(sptsdegs>d3,1,'first'),n1,d3);
            n3=(length(sptsdegs)-find(sptsdegs>d3,1,'first'))+n1;
        else
            n3=n1-find(sptsdegs>d3,1,'first');
        end
        ndx2 = circshift(ndx,-n1);
        dist2_len = length(ptsdegs);
        %fprintf('n1=%g n2=%g n3=%g len(edgepts)=%g\n',n1,n2,n3,length(ptsdegs));
        %fprintf('dist2=degree_distance(deg,ptsdegs(ndx2((%g-%g):end)));\n',dist2_len,n3);
        %all_pts = [ ptsradius(ndx2(1:n2)) ; ptsradius(ndx2((dist2_len-n3):end))];
        %fprintf('length(all_pts)=%g\n',length(all_pts));
        %fprintf('all_pts ');all_pts'
        newr = mean([ ptsradius(ndx2(1:n2)) ; ptsradius(ndx2((dist2_len-n3):end))]);
        newx = cpt(1)-newr*sind(-deg);
        newy = cpt(2)-newr*cosd(-deg);
        if(isnan(newx)||isnan(newy))
            fprintf('newr=%g, newx=%g, newy=%g\ndeg=%g cpt=(%g,%g)\n',newr,newx,newy,deg,cpt(1),cpt(2));
            error('NaN');
        end
        %fprintf('\tnewr=%g newx=%g newy=%g deg=%g\n',newr,newx,newy,deg);
    end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function get_edge_points_using_mouse()
        fig=figure(1);clf;set(fig,'MenuBar','none');%set(fig,'Position',[ get(0,'PointerLocation') 520 410]);
        image(load_cropped_data(cur_time));axis image;
        uicontrol(fig,'Style','pushbutton','String','Done','Position',[20 90 70 20],'Callback',@get_edge_point_done);
        if(~isempty(edgepts))
            hold on
            for i=1:size(edgepts,1)
                plot(edgepts(i,1),edgepts(i,2),'.w')
            end
            hold off
        end
        title('click and drag around the edge of the cell')
        OrigButtonDown=get(fig,'WindowButtonDownFcn');
        setappdata(fig,'OrigButtonDown',OrigButtonDown);
        set(fig,'WindowButtonDownFcn',{@get_edge_point_buttondown});
    end
    function get_edge_point_buttondown(h,evd)
        %disp('down')
        % get the values and store them in the figure's appdata
        props.WindowButtonMotionFcn = get(h,'WindowButtonMotionFcn');
        props.WindowButtonUpFcn = get(h,'WindowButtonUpFcn');
        setappdata(h,'TestGuiCallbacks',props);
        % set the new values for the WindowButtonMotionFcn and
        % WindowButtonUpFcn
        set(h,'WindowButtonMotionFcn',{@get_edge_point_buttonmotion})
        set(h,'WindowButtonUpFcn',{@get_edge_point_buttonup})
        % draw point
        %fprintf('BUTTONDOWN');
        %get(h);
        all_children = get(h,'Children');children=all_children(2);
        cp=get(children,'CurrentPoint');
        %fprintf('(%g,%g)\n',cp(1,1),cp(1,2));
        xlim = get(children,'XLim'); xlim = xlim(2)-xlim(1);
        ylim = get(children,'YLim'); ylim = ylim(2)-ylim(1);
        if( cp(1,1)>0 && cp(1,1) < xlim && cp(1,2)>0 && cp(1,2) < ylim)
            hold on
            plot(cp(1,1),cp(1,2),'.w')
            if(length(edgepts)>1)
                edgepts(end+1,:)=[cp(1,1) cp(1,2)];
            else
                edgepts(1,:)=[cp(1,1) cp(1,2)];
            end
            hold off
        end
    end
    function get_edge_point_buttonmotion(h,evd)
        % executes while the mouse moves
        all_children = get(h,'Children');children=all_children(2);
        cp=get(children,'CurrentPoint');
        %fprintf('(%g,%g)\n',cp(1,1),cp(1,2));
        xlim = get(children,'XLim'); xlim = xlim(2)-xlim(1);
        ylim = get(children,'YLim'); ylim = ylim(2)-ylim(1);
        if( cp(1,1)>0 && cp(1,1) < xlim && cp(1,2)>0 && cp(1,2) < ylim)
            hold on
            plot(cp(1,1),cp(1,2),'.w')
            edgepts(end+1,:)=[cp(1,1) cp(1,2)];
            hold off
        end
    end
    function get_edge_point_buttonup(h,evd)
        % executes when the mouse button is released
        %disp('up')
        % get the properties and restore them
        props = getappdata(h,'TestGuiCallbacks');
        set(h,props);
    end
    function get_edge_point_done(h,evd)
        fig=figure(1);set(fig,'MenuBar','none');%set(fig,'Position',[ get(0,'PointerLocation') 520 410]);
        orig = getappdata(fig,'OrigButtonDown');
        set(fig,'WindowButtonDownFcn',orig);
        % executes when the done button is pressed
        display_masking_figure__draw();
    end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function get_center_figure()
        fig=figure(1);clf;set(fig,'MenuBar','none');%set(fig,'Position',[ get(0,'PointerLocation') 520 410]);
        image(load_cropped_data(cur_time));axis image;
        title('click on the center of the cell');
        [x,y]=ginput(1);
        hold on
        plot(x,y,'xw','LineWidth',2);
        hold off;
        cpt=[x y];
    end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function display_masking_figure()
        %if center is not set
        if(isempty(cpt)),get_center_figure(),end
        %display_masking_figure__play();
        display_masking_figure__draw();
    end%%%%function display_masking_figure%%%%%%%%%%%%%%%%%%%%%%%%
    function display_masking_figure__play()
        clf;
        for t=1:tspan(end)
            image(load_cropped_data(t));axis image;
            title(sprintf('t=%g',t));
            if(~isempty(edgepts))
                hold on
                for i=1:size(edgepts,1)
                    plot(edgepts(i,1),edgepts(i,2),'.w')
                end
                hold off
            end
            if(~isempty(cpt))
                hold on
                plot(cpt(1),cpt(2),'xw','LineWidth',2);
                hold off;
            end
            drawnow;
            pause(.1);
        end
    end%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function display_masking_figure__draw()
        fig=figure(1);clf;set(fig,'MenuBar','none');%set(fig,'Position',[ get(0,'PointerLocation') 520 410]);
        image(load_cropped_data(cur_time));axis image;
        title(sprintf('t=%g',cur_time));
        if(~isempty(cpt))
            hold on
            plot(cpt(1),cpt(2),'xw','LineWidth',2);
            hold off;
        end
        uicontrol(fig,'Style','pushbutton','String','Set Center','Position',[20 50 70 20],'Callback',@display_masking_figure__setcenter);
        uicontrol(fig,'Style','pushbutton','String','Home','Position',[20 20 70 20],'Callback',@display_masking_figure__home);
        if(~isempty(edgepts))
            hold on
            for i=1:size(edgepts,1)
                plot(edgepts(i,1),edgepts(i,2),'.w')
            end
            hold off
        end
        if(cur_time<tspan(end))
        uicontrol(fig,'Style','pushbutton','String','Next>','Position',[300 360 70 20],'Callback',@display_masking_figure__advance_time);
        end
        if(cur_time>1)
        uicontrol(fig,'Style','pushbutton','String','<Prev','Position',[170 360 70 20],'Callback',@display_masking_figure__recede_time);
        end
        uicontrol(fig,'Style','pushbutton','String','Play','Position',[20 360 70 20],'Callback',@display_masking_figure__playmovie);
        uicontrol(fig,'Style','pushbutton','String','Save Frame','Position',[10 330 90 20],'Callback',@display_masking_figure__saveframe);
        uicontrol(fig,'Style','pushbutton','String','Save DataSet','Position',[10 300 90 20],'Callback',@display_masking_figure__save);
        %%%
        uicontrol(fig,'Style','pushbutton','String','Add pts','Position',[20 110 70 20],'Callback',@display_masking_figure__addpts);
        if(~isempty(edgepts))
        uicontrol(fig,'Style','pushbutton','String','Curve pts','Position',[10 140 90 20],'Callback',@display_masking_figure__curvepts);
        uicontrol(fig,'Style','pushbutton','String','Erase pts','Position',[20 90 70 20],'Callback',@display_masking_figure__erasepts);
        uicontrol(fig,'Style','pushbutton','String','Clear All','Position',[20 70 70 20],'Callback',@display_masking_figure__clearpts);
        end
        uicontrol(fig,'Style','text','String','Adjust Image','Position',[15 250,90 20]);
        uicontrol(fig,'Style','pushbutton','String','<','Position',[35 200 20 20],'Callback',@display_masking_figure__movebox_left);
        uicontrol(fig,'Style','pushbutton','String','>','Position',[55 200 20 20],'Callback',@display_masking_figure__movebox_right);
        uicontrol(fig,'Style','pushbutton','String','^','Position',[45 220 20 20],'Callback',@display_masking_figure__movebox_up);
        uicontrol(fig,'Style','pushbutton','String','v','Position',[45 180 20 20],'Callback',@display_masking_figure__movebox_down);
        %uicontrol(fig,'Style','pushbutton','String','Analyze','Position',[20 50 70 20],'Callback',@display_masking_figure__analyze);
        drawnow;
        set(fig,'KeyPressFcn',@display_masking_figure__keydown);
    end%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function display_masking_figure__keydown(h,event)
        set(fig,'KeyPressFcn','');
        if(strcmp(event.Key,'leftarrow'))
            if(length(event.Modifier)==1&&strcmp(event.Modifier{1},'shift'))
                %fprintf('move down\n');
                display_masking_figure__movebox_left(h,event);
            else
                display_masking_figure__recede_time(h,event);
                %fprintf('prev time\n');
            end
        elseif(strcmp(event.Key,'rightarrow'))
            if(length(event.Modifier)==1&&strcmp(event.Modifier{1},'shift'))
                display_masking_figure__movebox_right(h,event);
                %fprintf('move right\n');
            else
                display_masking_figure__advance_time(h,event);
                %fprintf('next time\n');
            end
        elseif(strcmp(event.Key,'uparrow'))
            if(length(event.Modifier)==1&&strcmp(event.Modifier{1},'shift'))
                display_masking_figure__movebox_up(h,event);
                %fprintf('move up\n');
            end
        elseif(strcmp(event.Key,'downarrow'))
            if(length(event.Modifier)==1&&strcmp(event.Modifier{1},'shift'))
                display_masking_figure__movebox_down(h,event);
                %fprintf('move down\n');
            end
        end
        set(fig,'KeyPressFcn',@display_masking_figure__keydown);
        figure(gcf);
    end%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function display_masking_figure__home(h,event)
display_cropping_figure();
    end%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function display_masking_figure__saveframe(h,event)
        [filename,path,filterindex] = uiputfile({'*.tif';'*.png'},'Save Frame As',sprintf('frame_%g.tif',cur_time));
        if filterindex>0
            A=load_cropped_data(cur_time);
            fprintf('Writing file: %s\n',strcat(path,filename));
            if(filterindex==1)
                imwrite(A,strcat(path,filename),'tif');
            elseif(filterindex==2)
                imwrite(A,strcat(path,filename),'png');
            else
                fprintf('Error saving file: unknown format\n');
            end
        end
    end%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function display_masking_figure__save(h,event)
        % copy data back to data set
        if(current_cell_selected<=0 || isempty(dataset_savefile))
            fprintf('current_cell_selected=%g, dataset_savefile=%s\n',current_cell_selected,dataset_savefile);
            error('can not save data');
        end
        cell_profile_data{current_cell_selected}.crop_lim=crop_lim;
        cell_profile_data{current_cell_selected}.edgepts=edgepts;
        cell_profile_data{current_cell_selected}.cpt=cpt;
        % save data
        save_dataset(dataset_savefile)
        %save 'profile_cell_data.mat' crop_lim edgepts cpt;
        %uisave({'crop_lim','edgepts','cpt'},'profile_cell_session.mat');
        fprintf('Date Set Save complete\n');
    end%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function display_masking_figure__analyze(h,event)
        analyse_data();
    end%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function display_masking_figure__analyzeall(h,event)
        analyse_all_data()
    end%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function display_masking_figure__setcenter(h,event)
        get_center_figure()
        display_masking_figure__draw()
    end%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function display_masking_figure__erasepts(h,event)
        fprintf('TODO\n');
    end%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function display_masking_figure__addpts(h,event)
        get_edge_points_using_mouse();
    end%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function display_masking_figure__curvepts(h,event)
        display_masking_figure__save(h,event);
        curve_edge_points();
    end%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function display_masking_figure__clearpts(h,event)
        edgepts=[];
        display_masking_figure__draw()
    end%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function display_masking_figure__movebox_up(h,event)
        %[top bottom left right]=crop_lim{t};
        crop_lim{cur_time}(1) = crop_lim{cur_time}(1)-1;
        crop_lim{cur_time}(2) = crop_lim{cur_time}(2)-1;
        display_masking_figure__draw();
    end%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function display_masking_figure__movebox_down(h,event)
        %[top bottom left right]=crop_lim{t};
        crop_lim{cur_time}(1) = crop_lim{cur_time}(1)+1;
        crop_lim{cur_time}(2) = crop_lim{cur_time}(2)+1;
        display_masking_figure__draw();
    end%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function display_masking_figure__movebox_left(h,event)
        %[top bottom left right]=crop_lim{t};
        crop_lim{cur_time}(3) = crop_lim{cur_time}(3)-1;
        crop_lim{cur_time}(4) = crop_lim{cur_time}(4)-1;
        display_masking_figure__draw();
    end%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function display_masking_figure__movebox_right(h,event)
        %[top bottom left right]=crop_lim{t};
        crop_lim{cur_time}(3) = crop_lim{cur_time}(3)+1;
        crop_lim{cur_time}(4) = crop_lim{cur_time}(4)+1;
        display_masking_figure__draw();
    end%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function display_masking_figure__playmovie(h,event)
        display_masking_figure__play();
        cur_time=1;
        display_masking_figure__draw();
    end%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function display_masking_figure__recede_time(h,event)
        if cur_time>1
            cur_time=cur_time-1; 
        end
        display_masking_figure__draw();
    end%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function display_masking_figure__advance_time(h,event)
        if(cur_time<length(tspan))
            cur_time=cur_time+1; 
        end
        display_masking_figure__draw();
    end%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function display_cropping_figure()
        fig=figure(1);clf;set(fig,'MenuBar','none');%set(fig,'Position',[ get(0,'PointerLocation') 520 410]);
        image(load_data(cur_time));axis image;
        if(current_cell_selected>0 && ~isempty(crop_lim{cur_time}))
            lim=crop_lim{cur_time};
            hold on
            plot([lim(3) lim(4)],[lim(1) lim(1)],'-w');
            plot([lim(3) lim(4)],[lim(2) lim(2)],'-w');
            plot([lim(3) lim(3)],[lim(1) lim(2)],'-w');
            plot([lim(4) lim(4)],[lim(1) lim(2)],'-w');
            hold off
        end
        title('A session analyizes a single cell');
        uicontrol(fig,'Style','pushbutton','String','Play Movie','Position',[10 350 90 20],'Callback',@display_cropping_figure__play);
        uicontrol(fig,'Style','pushbutton','String','New Session','Position',[10 320 90 20],'Callback',@display_cropping_figure__crop);
        uicontrol(fig,'Style','pushbutton','String','Save Data Set','Position',[10 380 90 20],'Callback',@display_cropping_figure__savedataset);
        %uicontrol(fig,'Style','pushbutton','String','Import Session','Position',[10 290 90 20],'Callback',@display_cropping_figure__loadsession);
        uicontrol(fig,'Style','pushbutton','String','CellProfiler','Position',[10 260 90 20],'Callback',@display_cropping_figure__useCellProfiler);
        uicontrol(fig,'Style','text','String',strcat(num2str(length(cell_profile_data)),' sessions'),'Position',[10 230 90 20]);
        if(~isempty(cell_profile_data))
            sess{1}='   ';
            for j=1:length(cell_profile_data)
                sess{j+1}=strcat('Cell ',num2str(j)); %#ok<AGROW>
            end
            h=uicontrol(fig,'Style','popup','String',sess,'Position',[10 200 90 20],'Callback',@display_cropping_figure__popupselectsess);
            if(current_cell_selected>0)
                set(h,'Value',current_cell_selected+1);
                %fprintf('set(h,value,%g)\n',current_cell_selected+1);
                uicontrol(fig,'Style','pushbutton','String','Analyze','Position',[10 170 90 20],'Callback',@display_cropping_figure__next);
                uicontrol(fig,'Style','pushbutton','String','Edit Cropping','Position',[10 140 90 20],'Callback',@display_cropping_figure__edit);
            else
                set(h,'Value',1);
                %fprintf('set(h,value,%g)\n',1);
            end

        end
        drawnow();
    end% display_cropping_figure%%%%%%%%%%%%%%%%%%%%
    function display_cropping_figure__next(h,event)
        display_masking_figure();
    end%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function display_cropping_figure__edit(h,event)
        crop_lim=cell(1);
        display_cropping_figure__get_cropbox();
        display_cropping_figure__draw();
    end%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function display_cropping_figure__savedataset(h,event)
        save_dataset(dataset_savefile)
        fprintf('Dataset Saved\n');
    end%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function display_cropping_figure__play(h,event)
        fig=figure(1);clf;set(fig,'MenuBar','none');%set(fig,'Position',[ get(0,'PointerLocation') 520 410]);
        for t=1:tspan(end)
            image(load_data(t));axis image;
            title(sprintf('t=%g',t));
            if(length(crop_lim)>=t && ~isempty(crop_lim{t}))
                lim=crop_lim{t};
                hold on
                plot([lim(3) lim(4)],[lim(1) lim(1)],'-w');
                plot([lim(3) lim(4)],[lim(2) lim(2)],'-w');
                plot([lim(3) lim(3)],[lim(1) lim(2)],'-w');
                plot([lim(4) lim(4)],[lim(1) lim(2)],'-w');
                hold off
            end
            drawnow;
            pause(.1);
        end
        display_cropping_figure();
    end%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function display_cropping_figure__useCellProfiler(h,event)
        %fprintf('TODO: use cell profiler to generate sessions\n');
        execute_CellProfiler();
    end%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function display_cropping_figure__popupselectsess(h,event)
        val = get(h,'Value');
        if(val==1)
            current_cell_selected=-1;
            fprintf('no session selected\n');
        elseif(val>1)
            current_cell_selected=val-1;
            fprintf('select session %g\n',current_cell_selected);
            crop_lim=cell_profile_data{current_cell_selected}.crop_lim;
            edgepts=cell_profile_data{current_cell_selected}.edgepts;
            cpt=cell_profile_data{current_cell_selected}.cpt;
        end
        display_cropping_figure();
    end%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function display_cropping_figure__crop(h,event)
        if(current_cell_selected>0)
            cell_profile_data{current_cell_selected}.crop_lim=crop_lim;
            cell_profile_data{current_cell_selected}.edgepts=edgepts;
            cell_profile_data{current_cell_selected}.cpt=cpt;
        end
        crop_lim=cell(1);
        edgepts=[];
        cpt=[];
        cur_time=1;
        display_cropping_figure__get_cropbox();
        display_cropping_figure__draw();
    end%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function display_cropping_figure__draw()
        fig=figure(1);clf;set(fig,'MenuBar','none');%set(fig,'Position',[ get(0,'PointerLocation') 520 410]);
        image(load_data(cur_time));axis image;
        %if(current_cell_selected>0)
        display_cropping_figure__plot_cropbox();
        %end
        title(sprintf('t=%g',cur_time));
        uicontrol(fig,'Style','pushbutton','String','<','Position',[20 200 20 20],'Callback',@display_cropping_figure__movebox_left);
        uicontrol(fig,'Style','pushbutton','String','>','Position',[40 200 20 20],'Callback',@display_cropping_figure__movebox_right);
        uicontrol(fig,'Style','pushbutton','String','^','Position',[30 220 20 20],'Callback',@display_cropping_figure__movebox_up);
        uicontrol(fig,'Style','pushbutton','String','v','Position',[30 180 20 20],'Callback',@display_cropping_figure__movebox_down);
        %fprintf('length(tspan)=%g cur_time=%g tspan(end)=%g\n',length(tspan),cur_time,tspan(end));
        if(cur_time<tspan(end))
        uicontrol(fig,'Style','pushbutton','String','Next>','Position',[300 360 70 20],'Callback',@display_cropping_figure__advance_time);
        end
        if(cur_time>1)
        uicontrol(fig,'Style','pushbutton','String','<Prev','Position',[170 360 70 20],'Callback',@display_cropping_figure__recede_time);
        end
        uicontrol(fig,'Style','pushbutton','String','Cancel','Position',[10 150 90 20],'Callback',@display_cropping_figure__restart);
        if(length(crop_lim)==length(tspan))
        uicontrol(fig,'Style','pushbutton','String','Finish','Position',[10 70 90 20],'Callback',@display_cropping_figure__done);
        else
        uicontrol(fig,'Style','pushbutton','String','Skip to End','Position',[10 120 90 20],'Callback',@display_cropping_figure__skiptoend);
        end
        %uicontrol(fig,'Style','pushbutton','String','Load','Position',[20 50 70 20],'Callback',@display_cropping_figure__load);
    end%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function display_cropping_figure__loadsession(h,event)
        % save previous data
        if(current_cell_selected>0)
            cell_profile_data{current_cell_selected}.crop_lim=crop_lim;
            cell_profile_data{current_cell_selected}.edgepts=edgepts;
            cell_profile_data{current_cell_selected}.cpt=cpt;
        end
        %%%
        fprintf('Loading session data\n');
        [FileName,PathName,FilterIndex] = uigetfile('*.mat','Import Session');
        if(FilterIndex>0)
            s=load(strcat(PathName,FileName));
            if(isfield(s,'crop_lim')),crop_lim = s.crop_lim;end
            if(isfield(s,'edgepts')),edgepts=s.edgepts;end
            if(isfield(s,'cpt')),cpt = s.cpt;end
        end
        if(length(crop_lim)==length(tspan))
            %HERE
            % add data to 
            current_cell_selected=length(cell_profile_data)+1;
            cell_profile_data{current_cell_selected}.crop_lim=crop_lim;
            cell_profile_data{current_cell_selected}.edgepts=edgepts;
            cell_profile_data{current_cell_selected}.cpt=cpt;
            fprintf('Session data loaded\n');
        else
            fprintf('load unsuccessful\n');
        end
        display_cropping_figure()
    end%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function display_cropping_figure__load(h,event)
        fid=fopen('profile_cell_data.mat');
        if(fid~=-1)
            fprintf('loading saved data\n');
            fclose(fid);
            s=load('profile_cell_data.mat');
            if(isfield(s,'crop_lim')),crop_lim = s.crop_lim;end
            if(isfield(s,'edgepts')),edgepts=s.edgepts;end
            if(isfield(s,'cpt')),cpt = s.cpt;end
        end
        cur_time=1;
        display_masking_figure();
    end%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function display_cropping_figure__movebox_up(h,event)
        %[top bottom left right]=crop_lim{t};
        crop_lim{cur_time}(1) = crop_lim{cur_time}(1)-1;
        crop_lim{cur_time}(2) = crop_lim{cur_time}(2)-1;
        display_cropping_figure__draw();
    end%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function display_cropping_figure__movebox_down(h,event)
        %[top bottom left right]=crop_lim{t};
        crop_lim{cur_time}(1) = crop_lim{cur_time}(1)+1;
        crop_lim{cur_time}(2) = crop_lim{cur_time}(2)+1;
        display_cropping_figure__draw();
    end%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function display_cropping_figure__movebox_left(h,event)
        %[top bottom left right]=crop_lim{t};
        crop_lim{cur_time}(3) = crop_lim{cur_time}(3)-1;
        crop_lim{cur_time}(4) = crop_lim{cur_time}(4)-1;
        display_cropping_figure__draw();
    end%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function display_cropping_figure__movebox_right(h,event)
        %[top bottom left right]=crop_lim{t};
        crop_lim{cur_time}(3) = crop_lim{cur_time}(3)+1;
        crop_lim{cur_time}(4) = crop_lim{cur_time}(4)+1;
        display_cropping_figure__draw();
    end%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function display_cropping_figure__done(h,event)
        cur_time=1;
        current_cell_selected=length(cell_profile_data)+1;
        fprintf('adding cell session %g\n',current_cell_selected);
        if(current_cell_selected>0)
            cell_profile_data{current_cell_selected}.crop_lim=crop_lim;
            cell_profile_data{current_cell_selected}.edgepts=edgepts;
            cell_profile_data{current_cell_selected}.cpt=cpt;
        end
        display_cropping_figure();
        %display_masking_figure();
    end%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function display_cropping_figure__recede_time(h,event)
        cur_time=cur_time-1; display_cropping_figure__draw();
    end%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function display_cropping_figure__advance_time(h,event)
        cur_time=cur_time+1; display_cropping_figure__draw();       
    end%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function display_cropping_figure__skiptoend(h,event)
        for i=1:length(tspan)
            cur_time=i;
            if(length(crop_lim)<cur_time || isempty(crop_lim{cur_time}))
                %fprintf('crop_lim{%g}=crop_lim{%g}\n',cur_time,cur_time-1);
                crop_lim{cur_time}=crop_lim{cur_time-1};
            end
        end
        display_cropping_figure__draw();
    end%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function display_cropping_figure__restart(h,event)              %#ok<*INUSD>
        cur_time=1;
        crop_lim = cell(1);
        clf;fprintf('restarting\n');
        display_cropping_figure;
    end%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function display_cropping_figure__get_cropbox()
        fig=figure(1);clf;set(fig,'MenuBar','none');%set(fig,'Position',[ get(0,'PointerLocation') 520 410]);
        %%%
        image(load_data(1));axis image;
        title('Drag a rectangle around a single yeast cell')
        drawnow;
        try
            %rect = [xmin ymin width height]
            rect=getrect(fig);  %blocking call
            %%%
            left = floor(rect(1));
            right = left+ceil(rect(3));
            top = floor(rect(2));
            bottom = top+ceil(rect(4));
            crop_lim{cur_time}=[top bottom left right];
            fprintf('cropping to (%g:%g,%g:%g) t=%g\n',top,bottom,left,right,1);
        catch err
            fprintf('caught error');err %#ok<NOPRT>
        end
    end%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function display_cropping_figure__plot_cropbox()
        %[top bottom left right]=crop_lim{t};
        if(length(crop_lim)<cur_time || isempty(crop_lim{cur_time}))
            %fprintf('crop_lim{%g}=crop_lim{%g}\n',cur_time,cur_time-1);
            crop_lim{cur_time}=crop_lim{cur_time-1};
        end
        lim=crop_lim{cur_time};
        hold on
        plot([lim(3) lim(4)],[lim(1) lim(1)],'-w');
        plot([lim(3) lim(4)],[lim(2) lim(2)],'-w');
        plot([lim(3) lim(3)],[lim(1) lim(2)],'-w');
        plot([lim(4) lim(4)],[lim(1) lim(2)],'-w');
        hold off
    end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

end
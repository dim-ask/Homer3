classdef GroupClass < TreeNodeClass
    
    properties % (Access = private)
        fileidx;
        nFiles;
        subjs;
        version;
    end
    
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Public methods
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    methods
        
        % ----------------------------------------------------------------------------------
        function obj = GroupClass(varargin)
            obj@TreeNodeClass(varargin);

            obj.version = Homer3_version('exclpath');
            obj.type  = 'group';
            if nargin>0
                if ischar(varargin{1}) && strcmp(varargin{1},'copy')
                    return;
                end
                fname = varargin{1};
            else
                return;
            end
            
            if isempty(fname)
                subj = SubjClass().empty;
            else
                subj = SubjClass(fname, 1, 1, 1);
            end
            
            % Derive obj name from the name of the root directory
            curr_dir = pwd;
            k = sort([findstr(curr_dir,'/') findstr(curr_dir,'\')]);
            name = curr_dir(k(end)+1:end);
            
            obj.name = name;
            obj.iGroup = 1;
            obj.type = 'group';
            obj.fileidx = 0;
            obj.nFiles = 0;
            obj.subjs = subj;
        end
        
        
        % ----------------------------------------------------------------------------------
        % Groups obj1 and obj2 are considered equivalent if their names
        % are equivalent and their subject sets are equivalent.
        % ----------------------------------------------------------------------------------
        function B = equivalent(obj1, obj2)
            B=1;
            if ~strcmp(obj1.name, obj2.name)
                B=0;
                return;
            end
            for i=1:length(obj1.subjs)
                j = existSubj(obj1, i, obj2);
                if j==0 || (obj1.subjs(i) ~= obj2.subjs(j))
                    B=0;
                    return;
                end
            end
            for i=1:length(obj2.subjs)
                j = existSubj(obj2, i, obj1);
                if j==0 || (obj2.subjs(i) ~= obj1.subjs(j))
                    B=0;
                    return;
                end
            end
        end
        
        
        % ----------------------------------------------------------------------------------
        function CopyFcalls(obj, varargin)
            if isa(varargin{1},'TreeNodeClass')
                procStream  = varargin{1}.procStream;
                type        = varargin{1}.type;
                if nargin>2
                    reg     = varargin{2};
                else
                    reg     = RegistriesClass.empty();
                end
            elseif isa(varargin{1},'ProcStreamClass')
                procStream  = varargin{1};
                type        = varargin{2};
                if nargin>3
                    reg     = varargin{3};
                else
                    reg     = RegistriesClass.empty();
                end
            end
            
            % Copy default procStream function call chain to all uninitialized nodes 
            % in the group
            switch(type)
                case 'group'
                    obj.procStream.CopyFcalls(procStream, reg);
                case 'subj'
                    for jj=1:length(obj.subjs)
                        obj.subjs(jj).procStream.CopyFcalls(procStream, reg);
                    end
                case 'run'
                    for jj=1:length(obj.subjs)
                        for kk=1:length(obj.subjs(jj).runs)
                            obj.subjs(jj).runs(kk).procStream.CopyFcalls(procStream, reg);
                        end
                    end
            end
        end

        
        
        % ----------------------------------------------------------------------------------
        function InitProcStream(obj, reg, procStreamCfgFile)
            if ~exist('procStreamCfgFile','var')
                procStreamCfgFile = '';
            end
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Find out if we need to ask user for processing options 
            % config file to initialize procStream.fcalls at the 
            % run, subject or group level. First try to find the proc 
            % input at each level from the save results groupresults.mat 
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            g = obj;
            s = obj.subjs(1);
            r = obj.subjs(1).runs(1);
            for jj=1:length(obj.subjs)
                if ~obj.subjs(jj).procStream.IsEmpty()
                    s = obj.subjs(jj);
                end
                for kk=1:length(obj.subjs(jj).runs)
                    if ~obj.subjs(jj).runs(kk).procStream.IsEmpty()
                        r = obj.subjs(jj).runs(kk);
                    end
                end
            end
            
            % Generate procStream defaults at each level with which to initialize
            % any uninitialized procStream.input
            g.CreateProcStreamDefault(reg);
            procStreamGroup = g.GetProcStreamDefault(reg);
            procStreamSubj = s.GetProcStreamDefault(reg);
            procStreamRun = r.GetProcStreamDefault(reg);
            
            % If any of the tree nodes still have unintialized procStream input, ask 
            % user for a config file to load it from 
            if g.procStream.IsEmpty() || s.procStream.IsEmpty() || r.procStream.IsEmpty()
                [fname, autoGenDefaultFile] = g.procStream.GetConfigFileName(procStreamCfgFile);                                
                
                % If user did not provide procStream config filename and file does not exist
                % then create a config file with the default contents
                if ~exist(fname, 'file')
                    procStreamGroup.SaveConfigFile(fname, 'group');
                    procStreamSubj.SaveConfigFile(fname, 'subj');
                    procStreamRun.SaveConfigFile(fname, 'run');
                end
                
                fprintf('Loading proc stream from %s\n', fname);
                
                % Load file to the first empty procStream in the dataTree at each processing level
                g.LoadProcStreamConfigFile(fname, reg);
                s.LoadProcStreamConfigFile(fname, reg);
                r.LoadProcStreamConfigFile(fname, reg);
                
                % Copy the loaded procStream at each processing level to all
                % nodes of that level that lack procStream 
                
                % If proc stream input is still empty it means the loaded config
                % did not have valid proc stream input. If that's the case we
                % load a default proc stream input
                if g.procStream.IsEmpty() || s.procStream.IsEmpty() || r.procStream.IsEmpty()
                    fprintf('Failed to load all function calls in proc stream config file. Loading default proc stream...\n');
                    g.CopyFcalls(procStreamGroup, 'group', reg);
                    g.CopyFcalls(procStreamSubj, 'subj', reg);
                    g.CopyFcalls(procStreamRun, 'run', reg);
                    
                    % If user asked default config file to be generated ...
                    if autoGenDefaultFile
                        fprintf('Generating default proc stream config file %s\n', fname);
                        
                        % Move exiting default config to same name with .bak extension
                        if ~exist([fname, '.bak'], 'file')
                            fprintf('Moving existing %s to %s.bak\n', fname, fname);
                            movefile(fname, [fname, '.bak']);
                        end
                        procStreamGroup.SaveConfigFile(fname, 'group');
                        procStreamSubj.SaveConfigFile(fname, 'subj');
                        procStreamRun.SaveConfigFile(fname, 'run');
                    end
                else
                    fprintf('Loading proc stream from %s\n', fname);
                    procStreamGroup.Copy(g.procStream);
                    procStreamSubj.Copy(s.procStream);
                    procStreamRun.Copy(r.procStream);
                    g.CopyFcalls(procStreamGroup, 'group', reg);
                    g.CopyFcalls(procStreamSubj, 'subj', reg);
                    g.CopyFcalls(procStreamRun, 'run', reg);
                end
            end
        end
            
        
                
        % ----------------------------------------------------------------------------------
        function Calc(obj)           
            % Recalculating result means deleting old results
            obj.procStream.output.Flush();

            % Calculate all subjs in this session
            s = obj.subjs;
            nSubj = length(s);
            nDataBlks = s(1).GetDataBlocksNum();
            tHRF_common = cell(nDataBlks,1);
            for iSubj = 1:nSubj
                s(iSubj).Calc();
                
                % Find smallest tHRF among the subjs. We should make this the common one.
                for iBlk = 1:nDataBlks
	                if isempty(tHRF_common{iBlk})
                        tHRF_common{iBlk} = s(iSubj).procStream.output.GetTHRF(iBlk);
                    elseif length(s(iSubj).procStream.output.GetTHRF(iBlk)) < length(tHRF_common{iBlk})
                        tHRF_common{iBlk} = s(iSubj).procStream.output.GetTHRF(iBlk);
                    end
                end
                
            end
           
            % Set common tHRF: make sure size of tHRF, dcAvg and dcAvg is same for
            % all subjs. Use smallest tHRF as the common one.
            for iSubj = 1:nSubj
                for iBlk = 1:length(tHRF_common)
                    s(iSubj).procStream.output.SettHRFCommon(tHRF_common{iBlk}, s(iSubj).name, s(iSubj).type, iBlk);
                end
            end
            
            % Instantiate all the variables that might be needed by
            % procStream.Calc() to calculate proc stream for this group
            vars = [];
            for iSubj = 1:nSubj
                vars.dodAvgSubjs{iSubj}    = s(iSubj).procStream.output.GetVar('dodAvg');
                vars.dodAvgStdSubjs{iSubj} = s(iSubj).procStream.output.GetVar('dodAvgStd');
                vars.dcAvgSubjs{iSubj}     = s(iSubj).procStream.output.GetVar('dcAvg');
                vars.dcAvgStdSubjs{iSubj}  = s(iSubj).procStream.output.GetVar('dcAvgStd');
                vars.tHRFSubjs{iSubj}      = s(iSubj).procStream.output.GetTHRF();
                vars.nTrialsSubjs{iSubj}   = s(iSubj).procStream.output.GetVar('nTrials');
                vars.SDSubjs{iSubj}        = s(iSubj).GetMeasList();
            end
            
            % Make variables in this group available to processing stream input
            obj.procStream.input.LoadVars(vars);

            % Calculate processing stream
            obj.procStream.Calc();
        end
        
        
        % ----------------------------------------------------------------------------------
        function Print(obj, indent)
            if ~exist('indent', 'var')
                indent = 0;
            end
            fprintf('%sGroup 1:\n', blanks(indent));
            obj.procStream.Print(indent+4);
            obj.procStream.output.Print(indent+4);
            for ii=1:length(obj.subjs)
                obj.subjs(ii).Print(indent+4);
            end
        end
        
        
        % ----------------------------------------------------------------------------------
        % Deletes derived data in procStream.output
        % ----------------------------------------------------------------------------------
        function Reset(obj)
            obj.procStream.output = ProcResultClass();
            for jj=1:length(obj.subjs)
                obj.subjs(jj).Reset();
            end
        end
        
        
    end   % Public methods
        
        
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Public Save/Load methods
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    methods
        
        % ----------------------------------------------------------------------------------
        function Load(obj)            
            group = [];
            if exist('./groupResults.mat','file')
                procdata = load( './groupResults.mat' );

                % Check compatibiliy with current version of Homer3
                if isproperty(procdata, 'group')
                    if isproperty(procdata.group, 'version')
                        if ischar(procdata.group.version) && includes(procdata.group.version,'Homer3')
                            group = procdata.group;
                        end
                    end
                end
            end
            
            if ~isempty(group)               
                % copy procStream.output from previous group to current group for
                % all nodes that still exist in the current group.
                hwait = waitbar(0,'Loading group');
                obj.Copy(group);
                close(hwait);
            else
                group = obj;
                if exist('./groupResults.mat','file')
                    fprintf('Warning: This folder contains old version of groupResults.mat. Will move it to groupResults_old.mat\n');
                    movefile('./groupResults.mat', './groupResults_old.mat')
                end
                save( './groupResults.mat','group' );
            end
        end
        
        
        % ----------------------------------------------------------------------------------
        function Save(obj, options)
            if ~exist('options','var')
                options = 'derived';
            end
            options_s = obj.parseSaveOptions(options);
            
            % Save derived data
            if options_s.derived
                group = obj;
                save( './groupResults.mat','group' );
            end
            
            % Save acquired data
            if options_s.acquired
                for ii=1:length(obj.subjs)
                    obj.subjs(ii).Save('derived');
                end
            end
        end
        
               
    end  % Public Save/Load methods
        
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Public Set/Get methods
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    methods
        
        
        % ----------------------------------------------------------------------------------
        function SD = GetSDG(obj)
            SD = obj.subjs(1).GetSDG();
        end
        
        
        % ----------------------------------------------------------------------------------
        function bbox = GetSdgBbox(obj)
            bbox = obj.subjs(1).GetSdgBbox();
        end
        
        
        % ----------------------------------------------------------------------------------
        function ch = GetMeasList(obj, iBlk)
            if ~exist('iBlk','var')
                iBlk=1;
            end
            ch = obj.subjs(1).GetMeasList(iBlk);
        end

        
        % ----------------------------------------------------------------------------------
        function wls = GetWls(obj)
            wls = obj.subjs(1).GetWls();
        end
        
        
        % ----------------------------------------------------------------------------------
        function [iDataBlks, ich] = GetDataBlocksIdxs(obj, ich)
            if nargin<2
                ich = [];
            end
            [iDataBlks, ich] = obj.subjs(1).GetDataBlocksIdxs(ich);
        end
        
        
        % ----------------------------------------------------------------------------------
        function n = GetDataBlocksNum(obj)
            n = obj.subjs(1).GetDataBlocksNum();
        end
        
    end      % Public Set/Get methods

        
       
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Conditions related methods
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    methods
        
        % ----------------------------------------------------------------------------------
        function RenameCondition(obj, oldname, newname)
            % Function to rename a condition. Important to remeber that changing the
            % condition involves 2 distinct well defined steps:
            %   a) For the current element change the name of the specified (old)
            %      condition for ONLY for ALL the acquired data elements under the
            %      currElem, be it run, subj, or group. In this step we DO NOT TOUCH
            %      the condition names of the run, subject or group.
            %   b) Rebuild condition names and tables of all the tree nodes group, subjects
            %      and runs same as if you were loading during Homer3 startup from the
            %      acquired data.
            %
            if ~exist('oldname','var') || ~ischar(oldname)
                return;
            end
            if ~exist('newname','var')  || ~ischar(newname)
                return;
            end            
            newname = obj.ErrCheckNewCondName(newname);
            if obj.err ~= 0
                return;
            end
            for ii=1:length(obj.subjs)
                obj.subjs(ii).RenameCondition(oldname, newname);
            end
        end

        
        
        % ----------------------------------------------------------------------------------
        function SetConditions(obj)            
            CondNames = {};
            for ii=1:length(obj.subjs)
                obj.subjs(ii).SetConditions();
                CondNames = [CondNames, obj.subjs(ii).GetConditions()];
            end
            obj.CondNames    = unique(CondNames);
            obj.CondNamesAll(obj.CondNames);
           
            % Now that we have all conditions, set the conditions across 
            % the whole group to these
            for ii=1:length(obj.subjs)
                obj.subjs(ii).SetConditions(obj.CondNames);
            end
            
            % Generate mapping of group conditions to subject conditions
            % used when averaging subject HRF to get group HRF
            obj.SetCondName2Subj();
            for iSubj=1:length(obj.subjs)
                obj.subjs(iSubj).SetCondName2Run();
                obj.subjs(iSubj).SetCondName2Group(obj.CondNames);
            end
            
            % For group this is an identity table
            obj.CondName2Group = 1:length(obj.CondNames);
        end
        
        
        % ----------------------------------------------------------------------------------
        % Generates mapping of group conditions to subject conditions
        % used when averaging subject HRF to get group HRF
        % ----------------------------------------------------------------------------------
        function SetCondName2Subj(obj)
            obj.procStream.input.CondName2Subj = zeros(length(obj.subjs),length(obj.CondNames));
            for iC=1:length(obj.CondNames)
                for iSubj=1:length(obj.subjs)
                    k = find(strcmp(obj.CondNames{iC}, obj.subjs(iSubj).GetConditions()));
                    if isempty(k)
                        obj.procStream.input.CondName2Subj(iSubj,iC) = 0;
                    else
                        obj.procStream.input.CondName2Subj(iSubj,iC) = k(1);
                    end
                end
            end
        end
        
        
        % ----------------------------------------------------------------------------------
        function CondNameIdx = GetCondNameIdx(obj, CondNameIdx)
            ;
        end
             
        
        % ----------------------------------------------------------------------------------
        function CondNames = GetConditionsActive(obj)
            CondNames = obj.CondNames;
            for ii=1:length(obj.subjs)
                CondNamesSubj = obj.subjs(ii).GetConditionsActive();
                for jj=1:length(CondNames)
                    k = find(strcmp(['-- ', CondNames{jj}], CondNamesSubj));
                    if ~isempty(k)
                        CondNames{jj} = ['-- ', CondNames{jj}];
                    end
                end
            end
        end
                
    end
    
    
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Private methods
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    methods  (Access = {})
        
        
        % ----------------------------------------------------------------------------------
        % Copy processing params (procInut and procStream.output) from
        % N2 to obj if obj and N2 are equivalent nodes
        % ----------------------------------------------------------------------------------
        function Copy(obj, G)
            if strcmp(obj.name,G.name)
                for i=1:length(obj.subjs)
                    j = obj.existSubj(i,G);
                    if (j>0)
                        obj.subjs(i).Copy(G.subjs(j));
                    end
                end
                if obj == G
                    obj.copyProcParamsFieldByField(G);
                end
            end           
        end
        
        
        % ----------------------------------------------------------------------------------
        % Check whether subject k'th subject from this group exists in group G and return
        % its index in G if it does exist. Else return 0.
        % ----------------------------------------------------------------------------------        
        function j = existSubj(obj, k, G)
            j=0;
            for i=1:length(G.subjs)
                if strcmp(obj.subjs(k).name, G.subjs(i).name)
                    j=i;
                    break;
                end
            end
        end
                
    end  % Private methods

end % classdef GroupClass < TreeNodeClass


function BatchHilbert(testname,cfg)
%BATCHHILBERT prevedeno do funkce pro opakovane volani ve skriptu - 30.1.2018
% cfg je konfigurace 
%15.9.2016 - AlloEgo zarovnani podle odpovedi
%25.5.2017 - Pridani reference a ERP

if ~exist('cfg','var'), cfg = struct; end; %pokud zadnou strukturu neuvedu, pouzivaji se defaultni nastaveni
if ~isfield(cfg,'hybernovat'), cfg.hybernovat = 0; end %jestli chci po konci skriptu pocitac uspat - ma prednost
if ~isfield(cfg,'vypnout'), cfg.vypnout = 0; end %jestli chci po konci skriptu pocitac vypnout (a nechci ho hybernovat) 
if ~isfield(cfg,'pouzetest'), cfg.pouzetest = 0; end %jestli chci jen otestovat pritomnost vsech souboru 
if ~isfield(cfg,'overwrite'), cfg.overwrite = 0;  end %jestil se maji prepsat puvodni data, nebo ohlasit chyba a pokracovat v dalsim souboru 
if ~isfield(cfg,'podilcasuodpovedi'), cfg.podilcasuodpovedi = 0; end  %jestli se maji epochy resamplovat na podil casu mezi podnetem a odpovedi
if ~isfield(cfg,'freqepochs'), cfg.freqepochs = 0; end %jestli se maji uklada frekvencni data od vsech epoch - velka data!
if ~isfield(cfg,'srovnejresp'), cfg.srovnejresp = 0; end %jestli se maji epochy zarovnava podle odpovedi
if ~isfield(cfg,'suffix'), cfg.suffix = ['Ep' datestr(now,'YYYY-mm')]; end %defaultne automaticka pripona rok-mesic
if ~isfield(cfg,'pacienti'), cfg.pacienti = {}; end; %muzu analyzovat jen vyber pacientu

if strcmp(testname,'menrot')
    setup = setup_menrot( cfg.srovnejresp ); %nacte nastaveni testu Menrot- 11.1.2018 - 0 = zarovnani podle podnetu, 1=zarovnani podle odpovedi
    pacienti = pacienti_menrot(); %nactu celou strukturu pacientu
elseif strcmp(testname,'aedist')
    setup = setup_aedist( cfg.srovnejresp ); %nacte nastaveni testu Aedist - 11.1.2018 - 0 = zarovnani podle podnetu, 1=zarovnani podle odpovedi
    pacienti = pacienti_aedist(); %nactu celou strukturu pacientu
elseif strcmp(testname,'ppa')
    setup = setup_ppa( cfg.srovnejresp ); %nacte nastaveni testu PPA - 6.2.2018 - 0 = zarovnani podle podnetu, 1=zarovnani podle odpovedi
    pacienti = pacienti_ppa(); %nactu celou strukturu pacientu
else
    error('nezname jmeno testu');
end

if numel(cfg.pacienti)>0
    pacienti = filterpac(pacienti,cfg.pacienti);
end
basedir = setup.basedir;
epochtime = setup.epochtime;
baseline = setup.baseline;
suffix = cfg.suffix;  % napriklad 'Ep2018-01' + Resp pokud serazeno podle odpovedi
if cfg.podilcasuodpovedi == 1, suffix = [suffix 'PCO']; end %pokud, pridam jeste na konec priponu
if cfg.srovnejresp,  suffix = [suffix 'RES']; end %pokud zarovnavam podle odpovedi, pridavam priponu
if cfg.freqepochs == 1, suffix = [suffix '_FE']; end %pokud, pridam jeste na konec priponu

prefix = setup.prefix;
stat_kats = setup.stat_kats;
stat_opak = setup.stat_opak;
subfolder = setup.subfolder;

frekvence = struct;
f=1;
frekvence(f).todo = 1;
frekvence(f).freq = [];
frekvence(f).freqname = 'ERP'; % ERP
f=f+1;
frekvence(f).todo = 1;
frekvence(f).freq = 50:10:150;
frekvence(f).freqname = '50-150'; % broad band gamma
f=f+1;
frekvence(f).todo = 1;
frekvence(f).freq = 7:2:15;
frekvence(f).freqname = '7-15'; % alpha
f=f+1;
frekvence(f).todo = 0;
frekvence(f).freq = 50:5:120;
frekvence(f).freqname = '50-120'; %gamma 2
f=f+1;
frekvence(f).todo = 1;
frekvence(f).freq = 30:5:50;
frekvence(f).freqname = '30-50'; % gamma
f=f+1;
frekvence(f).todo = 1;
frekvence(f).freq = 15:3:31;
frekvence(f).freqname = '15-31'; % beta
f=f+1;
frekvence(f).todo = 1;
frekvence(f).freq = 4:1:8;
frekvence(f).freqname = '4-8'; % theta fast
f=f+1;
frekvence(f).todo = 1;
frekvence(f).freq = 4:1:8;
frekvence(f).freqname = '4-8M'; % theta fast Morlet
frekvence(f).classname = 'Morlet'; % 
f=f+1;
frekvence(f).todo = 1;
frekvence(f).freq = 1:1:4;
frekvence(f).freqname = '1-4'; % theta slow
f=f+1;
frekvence(f).todo = 1;
frekvence(f).freq = 1:1:4;
frekvence(f).freqname = '1-4M'; % theta slow Morlet
frekvence(f).classname = 'Morlet'; % 
f=f+1;
frekvence(f).todo = 1;
frekvence(f).freq = 2:2:150;
frekvence(f).freqname = '2-150'; % all range
frekvence(f).prekryv = 0.5; % 50% prekryv sousednich frekvencnich pasem 

reference = struct;
r=1;
reference(r).todo = 1;
reference(r).name = 'refOrig';
reference(r).char = '';
r=2;
reference(r).todo = 1;
reference(r).name = 'refEle';
reference(r).char = 'e';
r=3;
reference(r).todo = 1;
reference(r).name = 'refHead';
reference(r).char = 'h';
r=4;
reference(r).todo = 1;
reference(r).name = 'refBipo';
reference(r).char = 'b';

logfilename = ['logs\BatchHilbert_' setup.prefix '_' datestr(now, 'yyyy-mm-dd_HH-MM-SS') '.log'];
[fileID,~] = fopen(logfilename,'wt'); %soubor na logovani prubehu
assert(fileID>=0,['nemohu otevrit soubor pro zapis: ' logfilename ]);
setuptext = setup2text(setup,cfg);
fprintf(fileID,setuptext); %ulozi setup do log souboru

%nejdriv overim, jestli existuje vsechno co potrebuju nacist
chybasoubor = false;

for p = 1:numel(pacienti)
    if pacienti(p).todo 
        
        if(exist([basedir pacienti(p).folder '\' pacienti(p).data],'file')~=2)
            if(exist([basedir pacienti(p).folder '\' subfolder '\'  pacienti(p).data],'file')~=2)
                msg = ['Data neexistuji: ' pacienti(p).folder '\\' pacienti(p).data];
                disp(msg); fprintf(fileID,[msg '\n']);
                chybasoubor = true; 
            else
                datafolder = ['\' subfolder];
            end
        else
            datafolder = '' ;
            fprintf(fileID,[ 'OK: ' pacienti(p).folder '\\' pacienti(p).data  '\n']);
        end;
        if(exist([basedir pacienti(p).folder '\' pacienti(p).header],'file')~=2)
            msg = ['Header neexistuje: ' pacienti(p).folder '\\' pacienti(p).header];
            disp(msg); fprintf(fileID,[msg '\n']);
            chybasoubor = true;
        else
            fprintf(fileID,[ 'OK: ' pacienti(p).folder '\\' pacienti(p).header  '\n']);
        end;
        if(exist([basedir pacienti(p).folder '\' subfolder '\' pacienti(p).psychopy],'file')~=2)
            msg = ['Psychopy soubor neexistuje: ' pacienti(p).folder '\\' subfolder '\\' pacienti(p).psychopy]; 
            disp(msg); fprintf(fileID,[msg '\n']);
            chybasoubor = true;  
        else
            fprintf(fileID,[ 'OK: ' pacienti(p).folder '\\' pacienti(p).psychopy  '\n']);
        end;
        if ~isempty(pacienti(p).rjepoch)  %muze byt prazne, pak se nevyrazuji zadne epochy     
            if(exist([basedir pacienti(p).folder '\' subfolder '\' pacienti(p).rjepoch],'file')~=2)
                msg = ['rjepoch neexistuje: ' pacienti(p).folder '\\' subfolder '\\' pacienti(p).rjepoch]; 
                disp(msg); fprintf(fileID,[msg '\n']);
                chybasoubor = true;                 
            else
                fprintf(fileID,[ 'OK: ' pacienti(p).folder '\\' pacienti(p).rjepoch  '\n']);
            end;            
        end
    end
end
if chybasoubor 
   fclose(fileID);
   error('nenalezeny nektere soubory');
else
    msg  = 'vsechny soubory ok';
    disp(msg);  fprintf(fileID,[msg '\n']); 
    if cfg.pouzetest
        disp('pouze test existence souboru');
        fclose(fileID);
        return; 
    end; 
end
if (cfg.vypnout),    disp('system se po dokonceni vypne'); end 
if (cfg.hybernovat), disp('system se po dokonceni uspi'); end
clear E d tabs fs mults header RjEpoch psychopy H ans; %vymazu, kdyby tam byl nejaky zbytek z predchozich pacientu
pocetcyklu = sum([frekvence.todo]) * sum([reference.todo]) * sum([pacienti.todo]);
cyklus = 1;
batchtimer = tic;
for f=1:numel(frekvence)        
    if frekvence(f).todo
        msg  =[ '*****' frekvence(f).freqname '*****' ]; 
        disp(msg);  fprintf(fileID,[msg '\n']); 
        if numel(frekvence(f).freq) == 0
            ERP = 1; 
        else
            ERP = 0; 
        end
        for p = 1:numel(pacienti)            
            if pacienti(p).todo
                msg  = [ ' ---- ' pacienti(p).folder ' ---- '];
                disp(msg);  fprintf(fileID,[msg '\n']); 
                for r = 1:numel(reference)
                    if reference(r).todo
                        msg  = [ ' ..... ' reference(r).name ' ..... ' datestr(now)]; %datum a cas
                        disp(msg);  fprintf(fileID,[msg '\n']); 
                        
                        try %i kdy bude nejaka chyba pri vyhodnoceni, chci pokracovat dalsimi soubory
                            if ERP
                                classname = 'CiEEG';
                                suffixclass = '.mat';
                            elseif isfield(frekvence(f),'classname') && strcmp(frekvence(f).classname,'Morlet')
                                classname = 'CMorlet';
                                suffixclass = '_CMorl.mat';
                            else
                                classname = 'CHilbert';
                                suffixclass = '_CHilb.mat'; 
                            end
                            outfilename = [ basedir pacienti(p).folder '\' subfolder '\' prefix ' ' classname ' ' frekvence(f).freqname ' ' sprintf('%.1f-%.1f',epochtime(1:2)) ' ' reference(r).name ' ' suffix];
                            if exist([outfilename suffixclass],'file')==2 && cfg.overwrite == 0                                
                                disp([ outfilename ' NEULOZENO, preskoceno']); 
                                fprintf(fileID,[ 'NEULOZENO,preskoceno: ' strrep(outfilename,'\','\\') ' - ' datestr(now) '\n']); 
                                continue; %dalsi polozka ve for cyklu     
                            elseif cfg.overwrite == 0
                                disp(['soubor zatim neexistuje - zpracovavam: ' outfilename suffixclass]); 
                            end
                            load([basedir pacienti(p).folder datafolder '\' pacienti(p).data]);
                            load([basedir pacienti(p).folder '\' pacienti(p).header]);
                            load([basedir pacienti(p).folder '\' subfolder '\' pacienti(p).psychopy]);
                            if strcmp(prefix,'PPA')
                                psychopy = ppa; clear ppa;
                            elseif strcmp(prefix ,'AEdist')
                                psychopy = aedist; clear aedist;
                            elseif strcmp(prefix ,'Menrot')
                                psychopy = menrot; clear menrot;
                            else
                                msg = ['neznamy typ testu ' prefix];
                                fprintf(fileID,[msg '\n']);
                                error(msg);
                            end
                            if ~isempty(pacienti(p).rjepoch)                         
                                load([basedir pacienti(p).folder '\' subfolder '\' pacienti(p).rjepoch]);
                            end
                            if ~exist('mults','var'),  mults = []; end
                            if ~exist('header','var'), header = []; end
                            if ERP
                                E = CiEEGData(d,tabs,fs,mults,header);
                                E.GetHHeader(H);
                                E.Filter([0 60],[],[],0); %odfiltruju vsechno nad 60Hz, nekreslim obrazek
                                E.Decimate(4); % ze 512 Hz na 128Hz. To staci na 60Hz signal                                
                            elseif strcmp(classname,'CMorlet')
                                E = CMorlet(d,tabs,fs,mults,header);
                                E.GetHHeader(H);
                            else
                                E = CHilbert(d,tabs,fs,mults,header);
                                E.GetHHeader(H);                                
                            end
                            clear d;                        
                            E.RejectChannels(pacienti(p).rjch);
                            epieventfile = [basedir pacienti(p).folder '\' subfolder '\' pacienti(p).epievents];
                            if exist(epieventfile,'file')==2 %pokud existuji, nactu epieventy
                                 load(epieventfile);
                                 E.GetEpiEvents(DE); 
                            else
                                disp(['epievent soubor neexistuje: ' epieventfile]);
                            end
                            if numel(reference(r).char)>0 %pokud se ma zmenit reference
                                E.ChangeReference(reference(r).char);
                            end
                            if ~ERP
                                if isfield(frekvence(f),'prekryv') && ~isempty(frekvence(f).prekryv)
                                    prekryv = frekvence(f).prekryv;
                                else
                                    prekryv = 0;  %defaultne je nulovy prekryv pasem                                    
                                end                                
                                E.PasmoFrekvence(frekvence(f).freq,[],prekryv,iff(cfg.podilcasuodpovedi,2,[])); 
                                    %pokud podilcasu, zdecimuju zatim jen malo, cele se mi ale nevejde do pameti
                            end
                            disp('extracting epochs ...');
                            if ERP
                                E.ExtractEpochs(psychopy,epochtime,baseline);                                 
                            else
                                E.ExtractEpochs(psychopy,epochtime,baseline,cfg.freqepochs);   
                            end
                            if exist('RjEpoch','var') %muze byt prazne, pak se nevyrazuji zadne epochy
                                E.RejectEpochs(RjEpoch); %globalne vyrazene epochy
                            end
                            if exist('RjEpochCh','var')
                                E.RejectEpochs(0,RjEpochCh); %epochy pro kazdy kanal zvlast
                            end
                            if cfg.podilcasuodpovedi == 1                            
                                E.ResampleEpochs(); % 27.11.2017 %resampluju na -1 1s podle casu odpovedi
                                E.Decimate(4); %ze 256 na 64hz, protoze jsem predtim v PasmoFrekvence decimoval jen 2x
                            end
                            E.ResponseSearch(0.1,stat_kats, stat_opak); %statistika s klouzavym oknem 100ms
                            disp('saving data ...');
                            
                            E.Save(outfilename);                            
                            disp([ pacienti(p).folder ' OK']); 
                            fprintf(fileID,[ 'OK: ' strrep(outfilename,'\','\\') ' - ' datestr(now) '\n']);
                            
                            clear E d tabs fs mults header RjEpoch psychopy H ans; 
                        catch exception 
                            errorMessage = sprintf('** Error in function %s() at line %d.\nError Message:\n%s', ...
                                exception.stack(1).name, exception.stack(1).line, exception.message);                            
                            disp(errorMessage);  fprintf(fileID,[errorMessage '\n']);  %#ok<DSPS> %zobrazim hlasku, zaloguju, ale snad to bude pokracovat dal                            
                            clear E d tabs fs mults header RjEpoch psychopy H ans; 
                        end    
                        cas = toc(batchtimer);
                        odhadcelehocasu = pocetcyklu/cyklus * cas;
                        fprintf(' %i/%i : cas zatim: %.1f min, zbyvajici cas %.1f min\n',cyklus,pocetcyklu,cas/60,(odhadcelehocasu - cas)/60); %vypisu v kolikatem jsem cyklu a kolik zbyva sekund do konce
                        cyklus = cyklus + 1;
                    end                    
                end
            end
        end
    end
end
fclose(fileID);
if cfg.hybernovat
    system('shutdown -h') 
elseif cfg.vypnout            
    system('shutdown -s')
end

end  %function
function pacienti= filterpac(pacienti,filter)
    pacremove = []; %seznam pacientu k vyrazeni
    for p = 1 : numel(pacienti)
        nalezen = false;
        for f = 1:numel(filter)
            if strfind(pacienti(p).folder,filter(f))
                nalezen = true; %pacient je uveden ve filtru
                break;
            end
        end
        if ~nalezen
            pacremove = [pacremove p]; %#ok<AGROW> %for cyklus porad bere z puvodniho array, takze ho nemuzu zmensovat v ramci for cyklu
        end
    end
    pacienti(pacremove) = [];
end
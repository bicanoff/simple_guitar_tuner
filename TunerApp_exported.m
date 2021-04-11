classdef TunerApp_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure               matlab.ui.Figure
        Gauge                  matlab.ui.control.SemicircularGauge
        TabGroup               matlab.ui.container.TabGroup
        StandardTab            matlab.ui.container.Tab
        Image                  matlab.ui.control.Image
        D3Button               matlab.ui.control.Button
        A2Button               matlab.ui.control.Button
        E2Button               matlab.ui.control.Button
        G3Button               matlab.ui.control.Button
        B3Button               matlab.ui.control.Button
        E4Button               matlab.ui.control.Button
        DropDTab               matlab.ui.container.Tab
        Image_2                matlab.ui.control.Image
        D3Button_2             matlab.ui.control.Button
        A2Button_2             matlab.ui.control.Button
        D2Button               matlab.ui.control.Button
        G3Button_2             matlab.ui.control.Button
        B3Button_2             matlab.ui.control.Button
        E4Button_2             matlab.ui.control.Button
        Baritone5Tab           matlab.ui.container.Tab
        Image_3                matlab.ui.control.Image
        A2Button_3             matlab.ui.control.Button
        E2Button_2             matlab.ui.control.Button
        B1Button               matlab.ui.control.Button
        D3Button_3             matlab.ui.control.Button
        F3Button               matlab.ui.control.Button
        B3Button_3             matlab.ui.control.Button
        CustomTab              matlab.ui.container.Tab
        DropDown_Note          matlab.ui.control.DropDown
        DropDown_Octave        matlab.ui.control.DropDown
        STARTButton            matlab.ui.control.Button
        NoteLabel              matlab.ui.control.Label
        OctaveLabel            matlab.ui.control.Label
        SettingsButton         matlab.ui.control.Button
        EditField_Tipp         matlab.ui.control.EditField
        EditField_MinusCent    matlab.ui.control.EditField
        EditField_PlucCent     matlab.ui.control.EditField
        EditField_CurrentNote  matlab.ui.control.EditField
    end

    
    properties (Access = private)
        % Hearing Range
        LowestFreq = 20; % in Hz
        HighestFreq = 20000; % in HZ
        
        CurrentNote;
        CurrentFrequency;
        
        Notes = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"];
        AllFrequencies; % All 128 Frequencies
        AllNotes; % All 128 Notes
        NotesAndFreqs; % 2x128 matrix [AllFrequencies;
                       %               AllNotes]
        Recorder;
        Fs = 48000; % Sampling rate
        
        % Zero Padding for a better frequency resolution
        FsIncr = 2; % Precision of 2 decimal places
        
        CentPrecision = 10;
        NBits = 16;
        NumChannels = 1;
        
        MinPeakHeight = 5e-5; % minimum amplitude for further analysis of the audio signal
        
        % Settings App properties
        DialogApp;
        PlayerID;
        RecorderID;
        RecDuration = 0.5; % recording time
    end
    
    methods (Access = private)
        
        function onOffComponents(app, status)
            app.SettingsButton.Enable = status;
            
            % Standard Tuning
            app.E4Button.Enable = status;
            app.B3Button.Enable = status;
            app.G3Button.Enable = status;
            app.E2Button.Enable = status;
            app.A2Button.Enable = status;
            app.D3Button.Enable = status;
            
            % Drop D Tuning
            app.E4Button_2.Enable = status;
            app.B3Button_2.Enable = status;
            app.G3Button_2.Enable = status;
            app.D2Button.Enable   = status;
            app.A2Button_2.Enable = status;
            app.D3Button_2.Enable = status;
            
            % Baritone(-5) Tuning
            app.B3Button_3.Enable = status;
            app.F3Button.Enable   = status;
            app.D3Button_3.Enable = status;
            app.B1Button.Enable   = status;
            app.E2Button_2.Enable = status;
            app.A2Button_3.Enable = status;
            
            % Custom Tuning
            app.STARTButton.Enable = status;
            app.DropDown_Octave.Enable = status;
            app.DropDown_Note.Enable = status;            
        end
        
        function populateFreq(app)
            for i = -1:9
                temp = strcat(app.Notes, num2str(i));
                app.AllNotes = [app.AllNotes temp];
            end
            
            app.AllNotes = app.AllNotes(1:128);                       
            
            for n = 0:127
                % https://www.translatorscafe.com/unit-converter/en-US/calculator/note-frequency/
                app.AllFrequencies(n+1) = round(440*2^((n-69)/12), app.FsIncr);
            end
            
            app.NotesAndFreqs = [app.AllNotes; app.AllFrequencies]; % 2x128 matrix with notes and frequencies
        end
        
        function updateAudioRecorder(app, newMicID)            
            % delete old audiorecorder
            if (~isempty(app.Recorder))
                delete(app.Recorder)
            end
            
            % create new audiorecorder
            app.Recorder = audiorecorder(app.Fs, app.NBits, app.NumChannels, newMicID);           
        end
        
        % https://www.translatorscafe.com/unit-converter/en-US/calculator/note-frequency/
        function results = setRefFreq(app)
            n = find(strcmp(app.AllNotes, app.CurrentNote)) - 1;
            results = 440*2^((n-69)/12);            
        end
        
        function initializeGauge(app, referenceFreq)
            centAbs = 50; % how wide is the scale
            
            app.Gauge.Limits = [centToFreq(app, referenceFreq, -centAbs) centToFreq(app, referenceFreq, centAbs)];
            app.Gauge.MajorTicks = [centToFreq(app, referenceFreq, -centAbs) centToFreq(app, referenceFreq, -centAbs/2) referenceFreq...
                centToFreq(app, referenceFreq, centAbs/2) centToFreq(app, referenceFreq, centAbs)]; % -50 -25 0 25 50 (in cents)
            % 1 cent = 1 MinorTick
            app.Gauge.MinorTicks = linspace(centToFreq(app, referenceFreq, -centAbs), centToFreq(app, referenceFreq, centAbs), centAbs*2);          
        end
        
        % Get the distance between the recorded frequency and the reference
        % frequency. If results < 0, then the frequency is too low, if > 0,
        % then the frequency is too high
        function results = centDistance(~, recordedFreq, referenceFreq)
            results = 1200*log2(recordedFreq/referenceFreq);            
        end
        
        % Get a frequency, that corresponds to a given cent distance using
        % the formula from the function centDistance
        % cents = 1200*log2(x/refFreq)
        % <=> log2(x/refFreq) = cents/1200
        % <=> log2(x) - log2(refFreq) = cents/1200
        % <=> log2(x) = cents/1200 + log2(refFreq)
        % <=> x = 2^(cents/1200 + log2(refFreq))
        function results = centToFreq(app, refFreq, cents)
            results = round(2^(cents/1200 + log2(refFreq)), app.FsIncr);
        end
        
        % Get a frequency, that corresponds to a given note
        function results = note2freq(app, note)
            index = find(strcmp(note, app.NotesAndFreqs(1,:)) == 1);
            freq = app.NotesAndFreqs(2, index);
            results = round(str2double(freq), app.FsIncr);
        end
        
        function tune(app)
            while true
                try
                    audioSignal = recordData(app);
                    if audioSignal == -1
                        break;
                    end
                    
                    % Windowing avoids the jumps in the periodic signal
                    % when the sampled signal does not have a whole number
                    % of periods
                    audioSignalWindow = audioSignal .* hann(numel(audioSignal));
                    
                    % Get 2-sided spectrum with Fast Fourier
                    spectrum = fft(audioSignalWindow, app.Fs * 10^app.FsIncr); % *100
                    
                    Nf = numel(spectrum);
                    dF = app.Fs/Nf; % = 0.01
                    
                    % Get 1-sided spectrum
                    spectrum1 = abs([spectrum(1) spectrum(2:Nf/2)' *2]) ./ Nf;
                    
                    % Cut out irrelevant frequencies
                    firstIndex = floor(app.LowestFreq/dF);
                    lastIndex = ceil(app.HighestFreq/dF);
                    spectrum1Cutted = spectrum1;
                    spectrum1Cutted(1:firstIndex) = 0;
                    spectrum1Cutted(lastIndex:end) = 0;
                    
                    % If there are no signigicant bins, then go to the next
                    % iteration
                    maxPeak = max(abs(spectrum1Cutted));
                    if maxPeak < app.MinPeakHeight
                        updateGauge(app, 0);
                        updatePlusMinusFields(app, 0, app.CurrentFrequency);
                        continue;
                    end
                    
                    % Normalize 1 sided spectrum
                    spectrum1CuttedNorm = spectrum1Cutted/max(spectrum1Cutted);
                    
                    % Get the fundamental frequency
                    f0 = getFundamentalFreq(app, spectrum1CuttedNorm, dF);
                    
                    % Refresh the gauge and the text fields
                    updatePlusMinusFields(app, f0, app.CurrentFrequency);
                    updateGauge(app, f0);                                
                                   
                catch e
                    waitfor(errordlg(['An error has occurred!' newline e.identifier newline ...
                        e.message], 'Error :('));
                    break;
                end
            end
        end 
        
        function results = recordData(app)
            try
                app.Recorder.record();
                pause(app.RecDuration);
                app.Recorder.stop();
                results = getaudiodata(app.Recorder);
            catch
                results = -1;
            end
        end
        
        function updateGauge(app, recordedFreq)
            app.Gauge.Value = recordedFreq;
        end
        
        % Refresh cents in the text fields
        function updatePlusMinusFields(app, recordedFreq, referenceFreq)
            app.EditField_MinusCent.Value = '';
            app.EditField_PlucCent.Value = '';
            
            if recordedFreq == 0
                app.EditField_Tipp.Value = "TOO QUIET!";
                app.EditField_CurrentNote.BackgroundColor = "w";
            else
                centDist = centDistance(app, recordedFreq, referenceFreq);
                if centDist < 0
                    app.EditField_MinusCent.Value = num2str(round(centDist));
                elseif centDist > 0
                    app.EditField_PlucCent.Value = "+" + num2str(round(centDist));
                end
                updateTippField(app, centDist);
            end
        end
        
        function updateTippField(app, centDist)
            if isinf(centDist)
                app.EditField_CurrentNote.BackgroundColor = 'w';
                app.EditField_Tipp.Value = "TOO QUIET!";
            else
                precision = app.CentPrecision;
                if centDist < -precision
                    app.EditField_CurrentNote.BackgroundColor = 'w';
                    app.EditField_Tipp.Value = "TOO LOW!";
                elseif centDist > precision
                    app.EditField_Tipp.Value = "TOO HIGH!";
                    app.EditField_CurrentNote.BackgroundColor = 'w';
                else 
                    app.EditField_Tipp.Value = "OK";
                    app.EditField_CurrentNote.BackgroundColor = 'g';
                end
            end
        end
        
        % https://www.researchgate.net/publication/45888076_A_Digital_Guitar_Tuner
        function results = getFundamentalFreq(app, spectrum1CuttedNorm, dF)
            addSpectrum = spectrum1CuttedNorm;
            
            % Down Sampling & Spectrum Addition
            for i = 2:5
                tempSpectrum = zeros(1, numel(spectrum1CuttedNorm));
                n = numel(spectrum1CuttedNorm(1:i:end));
                tempSpectrum(1:n) = spectrum1CuttedNorm(1:i:end);
                addSpectrum = addSpectrum + tempSpectrum;
            end
            
            % Get the interval with the fundamental frequency
            reference = app.CurrentFrequency;
            from = mean([reference reference/2]); % half an octave lower
            to = mean([reference reference*2]);   % hald an octave higher
            
            % Cut out not important frequencies
            fromIndex = floor(from/dF);
            toIndex = ceil(to/dF);
            addSpectrum(1:fromIndex) = 0;
            addSpectrum(toIndex:end) = 0;
            
            [~, loc] = max(addSpectrum);
            results = round(loc*dF, app.FsIncr);
        end
        
        % https://de.mathworks.com/help/signal/ug/generating-guitar-chords-using-the-karplus-strong-algorithm.html
        function playFreq(app, freq)
            ID = app.PlayerID;
            fs = app.Fs;
            nBits = app.NBits;
            duration = 1;
            
            x = zeros(fs*duration, 1);
            delay = round(fs/freq);
            
            b = firls(42, [0 1/delay 2/delay 1], [0 0 1 1]);
            a = [1 zeros(1, delay) -0.5 -0.5];
            
            zi = rand(max(length(b), length(a))-1,1);
            note = filter(b, a, x, zi);
            
            % normalize the sound
            note = note - mean(note);
            note = note / max(abs(note));
            
            hplayer = audioplayer(note, fs, nBits, ID);
            playblocking(hplayer);                    
        end
    end
    
    methods (Access = public)
        
        function updateFromSettings(app, micID, playerID, recDuration)
            app.RecorderID = micID;
            updateAudioRecorder(app, micID);
            app.PlayerID = playerID;
            app.RecDuration = recDuration;
        end
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            onOffComponents (app, 'off');
            
            % Custom Mode
            app.DropDown_Note.Items = app.Notes; 
            app.DropDown_Octave.Items = string(1:5); 
            
            populateFreq(app); % create 2x128 matrix with all notes and frequencies
            
            dinf = audiodevinfo();
            devID = dinf.input(1).ID; % internal microphone
            app.PlayerID = dinf.output(1).ID; % internal player
            
            % waiting for the user to close the settings
            % https://de.mathworks.com/help/matlab/creating_guis/creating-multiwindow-apps-in-app-designer.html
            waitfor(SettingsApp(app, devID, app.PlayerID, app.RecDuration));
            
            % If no mic was chosen
            if isempty(app.RecorderID)
                app.RecorderID = devID;
            end
            
            app.Recorder = audiorecorder(app.Fs, app.NBits, app.NumChannels, app.RecorderID);
            
            onOffComponents (app, 'on');
        end

        % Button pushed function: A2Button, A2Button_2, A2Button_3, 
        % B1Button, B3Button, B3Button_2, B3Button_3, D2Button, 
        % D3Button, D3Button_2, D3Button_3, E2Button, E2Button_2, 
        % E4Button, E4Button_2, F3Button, G3Button, G3Button_2
        function E2ButtonPushed(app, event)
            note = event.Source.Text;
            app.EditField_CurrentNote.Value = note;
            app.EditField_CurrentNote.BackgroundColor = 'w';
            app.EditField_MinusCent.Value = '';
            app.EditField_PlucCent.Value = '';
            app.EditField_Tipp.Value = '';
            
            app.CurrentNote = note;
            app.CurrentFrequency = setRefFreq(app);
            initializeGauge(app, app.CurrentFrequency);
            freq = note2freq(app, note);
            playFreq(app, freq);
            tune(app);
        end

        % Button pushed function: SettingsButton
        function SettingsButtonPushed(app, event)
            % Disable Buttons while dialog is open
            onOffComponents(app, 'off');
            micID = get(app.Recorder, "DeviceID"); % internal mic
            speakerID = app.PlayerID;
            recDuration = app.RecDuration;
            app.DialogApp = SettingsApp(app, micID, speakerID, recDuration);            
            waitfor(app.DialogApp);
            onOffComponents(app, 'on');
        end

        % Close request function: UIFigure
        function UIFigureCloseRequest(app, event)
            onOffComponents(app, 'off');
            if ~isempty(app.DialogApp)
                delete(app.DialogApp);
            end
            delete(app);            
        end

        % Button pushed function: STARTButton
        function STARTButtonPushed(app, event)
            ev.Source.Text = [app.DropDown_Note.Value app.DropDown_Octave.Value];
            E2ButtonPushed(app, ev);
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Color = [0.651 0.651 0.651];
            app.UIFigure.Position = [100 100 462 748];
            app.UIFigure.Name = 'MATLAB App';
            app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @UIFigureCloseRequest, true);

            % Create Gauge
            app.Gauge = uigauge(app.UIFigure, 'semicircular');
            app.Gauge.BackgroundColor = [0 0 0];
            app.Gauge.ScaleColors = [1 0 0;1 1 0;0 1 0;1 1 0;1 0 0];
            app.Gauge.FontSize = 14;
            app.Gauge.FontWeight = 'bold';
            app.Gauge.FontColor = [1 1 1];
            app.Gauge.Position = [24 469 414 224];

            % Create TabGroup
            app.TabGroup = uitabgroup(app.UIFigure);
            app.TabGroup.Position = [6 9 451 456];

            % Create StandardTab
            app.StandardTab = uitab(app.TabGroup);
            app.StandardTab.Title = 'Standard';
            app.StandardTab.BackgroundColor = [0.8 0.8 0.8];

            % Create Image
            app.Image = uiimage(app.StandardTab);
            app.Image.Position = [71 7 307 419];
            app.Image.ImageSource = 'Guitar.png';

            % Create D3Button
            app.D3Button = uibutton(app.StandardTab, 'push');
            app.D3Button.ButtonPushedFcn = createCallbackFcn(app, @E2ButtonPushed, true);
            app.D3Button.BackgroundColor = [0 0 0];
            app.D3Button.FontSize = 14;
            app.D3Button.FontWeight = 'bold';
            app.D3Button.FontColor = [1 1 1];
            app.D3Button.Position = [46 326 53 54];
            app.D3Button.Text = 'D3';

            % Create A2Button
            app.A2Button = uibutton(app.StandardTab, 'push');
            app.A2Button.ButtonPushedFcn = createCallbackFcn(app, @E2ButtonPushed, true);
            app.A2Button.BackgroundColor = [0 0 0];
            app.A2Button.FontSize = 14;
            app.A2Button.FontWeight = 'bold';
            app.A2Button.FontColor = [1 1 1];
            app.A2Button.Position = [46 189 53 54];
            app.A2Button.Text = 'A2';

            % Create E2Button
            app.E2Button = uibutton(app.StandardTab, 'push');
            app.E2Button.ButtonPushedFcn = createCallbackFcn(app, @E2ButtonPushed, true);
            app.E2Button.BackgroundColor = [0 0 0];
            app.E2Button.FontSize = 14;
            app.E2Button.FontWeight = 'bold';
            app.E2Button.FontColor = [1 1 1];
            app.E2Button.Position = [46 51 53 54];
            app.E2Button.Text = 'E2';

            % Create G3Button
            app.G3Button = uibutton(app.StandardTab, 'push');
            app.G3Button.ButtonPushedFcn = createCallbackFcn(app, @E2ButtonPushed, true);
            app.G3Button.BackgroundColor = [0 0 0];
            app.G3Button.FontSize = 14;
            app.G3Button.FontWeight = 'bold';
            app.G3Button.FontColor = [1 1 1];
            app.G3Button.Position = [351 326 53 54];
            app.G3Button.Text = 'G3';

            % Create B3Button
            app.B3Button = uibutton(app.StandardTab, 'push');
            app.B3Button.ButtonPushedFcn = createCallbackFcn(app, @E2ButtonPushed, true);
            app.B3Button.BackgroundColor = [0 0 0];
            app.B3Button.FontSize = 14;
            app.B3Button.FontWeight = 'bold';
            app.B3Button.FontColor = [1 1 1];
            app.B3Button.Position = [351 189 53 54];
            app.B3Button.Text = 'B3';

            % Create E4Button
            app.E4Button = uibutton(app.StandardTab, 'push');
            app.E4Button.ButtonPushedFcn = createCallbackFcn(app, @E2ButtonPushed, true);
            app.E4Button.BackgroundColor = [0 0 0];
            app.E4Button.FontSize = 14;
            app.E4Button.FontWeight = 'bold';
            app.E4Button.FontColor = [1 1 1];
            app.E4Button.Position = [351 51 53 54];
            app.E4Button.Text = 'E4';

            % Create DropDTab
            app.DropDTab = uitab(app.TabGroup);
            app.DropDTab.Title = 'Drop D';
            app.DropDTab.BackgroundColor = [0.8 0.8 0.8];

            % Create Image_2
            app.Image_2 = uiimage(app.DropDTab);
            app.Image_2.Position = [71 7 307 419];
            app.Image_2.ImageSource = 'Guitar.png';

            % Create D3Button_2
            app.D3Button_2 = uibutton(app.DropDTab, 'push');
            app.D3Button_2.ButtonPushedFcn = createCallbackFcn(app, @E2ButtonPushed, true);
            app.D3Button_2.BackgroundColor = [0 0 0];
            app.D3Button_2.FontSize = 14;
            app.D3Button_2.FontWeight = 'bold';
            app.D3Button_2.FontColor = [1 1 1];
            app.D3Button_2.Position = [46 326 53 54];
            app.D3Button_2.Text = 'D3';

            % Create A2Button_2
            app.A2Button_2 = uibutton(app.DropDTab, 'push');
            app.A2Button_2.ButtonPushedFcn = createCallbackFcn(app, @E2ButtonPushed, true);
            app.A2Button_2.BackgroundColor = [0 0 0];
            app.A2Button_2.FontSize = 14;
            app.A2Button_2.FontWeight = 'bold';
            app.A2Button_2.FontColor = [1 1 1];
            app.A2Button_2.Position = [46 189 53 54];
            app.A2Button_2.Text = 'A2';

            % Create D2Button
            app.D2Button = uibutton(app.DropDTab, 'push');
            app.D2Button.ButtonPushedFcn = createCallbackFcn(app, @E2ButtonPushed, true);
            app.D2Button.BackgroundColor = [0 0 0];
            app.D2Button.FontSize = 14;
            app.D2Button.FontWeight = 'bold';
            app.D2Button.FontColor = [1 1 1];
            app.D2Button.Position = [46 51 53 54];
            app.D2Button.Text = 'D2';

            % Create G3Button_2
            app.G3Button_2 = uibutton(app.DropDTab, 'push');
            app.G3Button_2.ButtonPushedFcn = createCallbackFcn(app, @E2ButtonPushed, true);
            app.G3Button_2.BackgroundColor = [0 0 0];
            app.G3Button_2.FontSize = 14;
            app.G3Button_2.FontWeight = 'bold';
            app.G3Button_2.FontColor = [1 1 1];
            app.G3Button_2.Position = [351 326 53 54];
            app.G3Button_2.Text = 'G3';

            % Create B3Button_2
            app.B3Button_2 = uibutton(app.DropDTab, 'push');
            app.B3Button_2.ButtonPushedFcn = createCallbackFcn(app, @E2ButtonPushed, true);
            app.B3Button_2.BackgroundColor = [0 0 0];
            app.B3Button_2.FontSize = 14;
            app.B3Button_2.FontWeight = 'bold';
            app.B3Button_2.FontColor = [1 1 1];
            app.B3Button_2.Position = [351 189 53 54];
            app.B3Button_2.Text = 'B3';

            % Create E4Button_2
            app.E4Button_2 = uibutton(app.DropDTab, 'push');
            app.E4Button_2.ButtonPushedFcn = createCallbackFcn(app, @E2ButtonPushed, true);
            app.E4Button_2.BackgroundColor = [0 0 0];
            app.E4Button_2.FontSize = 14;
            app.E4Button_2.FontWeight = 'bold';
            app.E4Button_2.FontColor = [1 1 1];
            app.E4Button_2.Position = [351 51 53 54];
            app.E4Button_2.Text = 'E4';

            % Create Baritone5Tab
            app.Baritone5Tab = uitab(app.TabGroup);
            app.Baritone5Tab.Title = 'Baritone (-5)';
            app.Baritone5Tab.BackgroundColor = [0.8 0.8 0.8];

            % Create Image_3
            app.Image_3 = uiimage(app.Baritone5Tab);
            app.Image_3.Position = [71 7 307 419];
            app.Image_3.ImageSource = 'Guitar.png';

            % Create A2Button_3
            app.A2Button_3 = uibutton(app.Baritone5Tab, 'push');
            app.A2Button_3.ButtonPushedFcn = createCallbackFcn(app, @E2ButtonPushed, true);
            app.A2Button_3.BackgroundColor = [0 0 0];
            app.A2Button_3.FontSize = 14;
            app.A2Button_3.FontWeight = 'bold';
            app.A2Button_3.FontColor = [1 1 1];
            app.A2Button_3.Position = [46 326 53 54];
            app.A2Button_3.Text = 'A2';

            % Create E2Button_2
            app.E2Button_2 = uibutton(app.Baritone5Tab, 'push');
            app.E2Button_2.ButtonPushedFcn = createCallbackFcn(app, @E2ButtonPushed, true);
            app.E2Button_2.BackgroundColor = [0 0 0];
            app.E2Button_2.FontSize = 14;
            app.E2Button_2.FontWeight = 'bold';
            app.E2Button_2.FontColor = [1 1 1];
            app.E2Button_2.Position = [46 189 53 54];
            app.E2Button_2.Text = 'E2';

            % Create B1Button
            app.B1Button = uibutton(app.Baritone5Tab, 'push');
            app.B1Button.ButtonPushedFcn = createCallbackFcn(app, @E2ButtonPushed, true);
            app.B1Button.BackgroundColor = [0 0 0];
            app.B1Button.FontSize = 14;
            app.B1Button.FontWeight = 'bold';
            app.B1Button.FontColor = [1 1 1];
            app.B1Button.Position = [46 51 53 54];
            app.B1Button.Text = 'B1';

            % Create D3Button_3
            app.D3Button_3 = uibutton(app.Baritone5Tab, 'push');
            app.D3Button_3.ButtonPushedFcn = createCallbackFcn(app, @E2ButtonPushed, true);
            app.D3Button_3.BackgroundColor = [0 0 0];
            app.D3Button_3.FontSize = 14;
            app.D3Button_3.FontWeight = 'bold';
            app.D3Button_3.FontColor = [1 1 1];
            app.D3Button_3.Position = [351 326 53 54];
            app.D3Button_3.Text = 'D3';

            % Create F3Button
            app.F3Button = uibutton(app.Baritone5Tab, 'push');
            app.F3Button.ButtonPushedFcn = createCallbackFcn(app, @E2ButtonPushed, true);
            app.F3Button.BackgroundColor = [0 0 0];
            app.F3Button.FontSize = 14;
            app.F3Button.FontWeight = 'bold';
            app.F3Button.FontColor = [1 1 1];
            app.F3Button.Position = [351 189 53 54];
            app.F3Button.Text = 'F#3';

            % Create B3Button_3
            app.B3Button_3 = uibutton(app.Baritone5Tab, 'push');
            app.B3Button_3.ButtonPushedFcn = createCallbackFcn(app, @E2ButtonPushed, true);
            app.B3Button_3.BackgroundColor = [0 0 0];
            app.B3Button_3.FontSize = 14;
            app.B3Button_3.FontWeight = 'bold';
            app.B3Button_3.FontColor = [1 1 1];
            app.B3Button_3.Position = [351 51 53 54];
            app.B3Button_3.Text = 'B3';

            % Create CustomTab
            app.CustomTab = uitab(app.TabGroup);
            app.CustomTab.Title = 'Custom';
            app.CustomTab.BackgroundColor = [0.8 0.8 0.8];

            % Create DropDown_Note
            app.DropDown_Note = uidropdown(app.CustomTab);
            app.DropDown_Note.Items = {};
            app.DropDown_Note.FontWeight = 'bold';
            app.DropDown_Note.FontColor = [1 1 1];
            app.DropDown_Note.BackgroundColor = [0 0 0];
            app.DropDown_Note.Position = [77 342 100 22];
            app.DropDown_Note.Value = {};

            % Create DropDown_Octave
            app.DropDown_Octave = uidropdown(app.CustomTab);
            app.DropDown_Octave.Items = {};
            app.DropDown_Octave.FontWeight = 'bold';
            app.DropDown_Octave.FontColor = [1 1 1];
            app.DropDown_Octave.BackgroundColor = [0 0 0];
            app.DropDown_Octave.Position = [272 342 100 22];
            app.DropDown_Octave.Value = {};

            % Create STARTButton
            app.STARTButton = uibutton(app.CustomTab, 'push');
            app.STARTButton.ButtonPushedFcn = createCallbackFcn(app, @STARTButtonPushed, true);
            app.STARTButton.BackgroundColor = [0 0 0];
            app.STARTButton.FontSize = 14;
            app.STARTButton.FontWeight = 'bold';
            app.STARTButton.FontColor = [1 1 1];
            app.STARTButton.Position = [176 242 100 47];
            app.STARTButton.Text = 'START';

            % Create NoteLabel
            app.NoteLabel = uilabel(app.CustomTab);
            app.NoteLabel.FontSize = 14;
            app.NoteLabel.FontWeight = 'bold';
            app.NoteLabel.Position = [77 371 37 22];
            app.NoteLabel.Text = 'Note';

            % Create OctaveLabel
            app.OctaveLabel = uilabel(app.CustomTab);
            app.OctaveLabel.FontSize = 14;
            app.OctaveLabel.FontWeight = 'bold';
            app.OctaveLabel.Position = [272 371 52 22];
            app.OctaveLabel.Text = 'Octave';

            % Create SettingsButton
            app.SettingsButton = uibutton(app.UIFigure, 'push');
            app.SettingsButton.ButtonPushedFcn = createCallbackFcn(app, @SettingsButtonPushed, true);
            app.SettingsButton.BackgroundColor = [0 0 0];
            app.SettingsButton.FontSize = 14;
            app.SettingsButton.FontWeight = 'bold';
            app.SettingsButton.FontColor = [1 1 1];
            app.SettingsButton.Position = [349 711 100 24];
            app.SettingsButton.Text = 'Settings';

            % Create EditField_Tipp
            app.EditField_Tipp = uieditfield(app.UIFigure, 'text');
            app.EditField_Tipp.Editable = 'off';
            app.EditField_Tipp.HorizontalAlignment = 'center';
            app.EditField_Tipp.Position = [182 692 100 43];

            % Create EditField_MinusCent
            app.EditField_MinusCent = uieditfield(app.UIFigure, 'text');
            app.EditField_MinusCent.Editable = 'off';
            app.EditField_MinusCent.HorizontalAlignment = 'center';
            app.EditField_MinusCent.Position = [14 646 60 39];

            % Create EditField_PlucCent
            app.EditField_PlucCent = uieditfield(app.UIFigure, 'text');
            app.EditField_PlucCent.Editable = 'off';
            app.EditField_PlucCent.HorizontalAlignment = 'center';
            app.EditField_PlucCent.Position = [389 646 60 39];

            % Create EditField_CurrentNote
            app.EditField_CurrentNote = uieditfield(app.UIFigure, 'text');
            app.EditField_CurrentNote.Editable = 'off';
            app.EditField_CurrentNote.HorizontalAlignment = 'center';
            app.EditField_CurrentNote.Position = [213 580 45 22];

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = TunerApp_exported

            runningApp = getRunningApp(app);

            % Check for running singleton app
            if isempty(runningApp)

                % Create UIFigure and components
                createComponents(app)

                % Register the app with App Designer
                registerApp(app, app.UIFigure)

                % Execute the startup function
                runStartupFcn(app, @startupFcn)
            else

                % Focus the running singleton app
                figure(runningApp.UIFigure)

                app = runningApp;
            end

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end
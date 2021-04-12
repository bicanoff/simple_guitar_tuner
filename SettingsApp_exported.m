classdef SettingsApp_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure              matlab.ui.Figure
        SettingsLabel         matlab.ui.control.Label
        RecTimesLabel         matlab.ui.control.Label
        SoundInputLabel       matlab.ui.control.Label
        SoundOutputLabel      matlab.ui.control.Label
        SaveButton            matlab.ui.control.Button
        CancelButton          matlab.ui.control.Button
        RecTimeSlider         matlab.ui.control.Slider
        DropDown_SoundInput   matlab.ui.control.DropDown
        DropDown_SoundOutput  matlab.ui.control.DropDown
    end

    
    properties (Access = private)
        CallingApp % Description
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app, mainapp, micID, speakerID, recDuration)
            app.CallingApp = mainapp;
            app.RecTimeSlider.Value = recDuration;
            
            app.DropDown_SoundInput.Items = {audiodevinfo().input().Name};
            micName = audiodevinfo(1, micID);
            app.DropDown_SoundInput.Value = micName;
            
            app.DropDown_SoundOutput.Items = {audiodevinfo().output().Name};
            speakerName = audiodevinfo(0, speakerID);
            app.DropDown_SoundOutput.Value = speakerName;                      
        end

        % Close request function: UIFigure
        function UIFigureCloseRequest(app, event)
            delete(app)
        end

        % Button pushed function: SaveButton
        function SaveButtonPushed(app, event)
            micID = audiodevinfo(1, app.DropDown_SoundInput.Value);
            speakerID = audiodevinfo(0, app.DropDown_SoundOutput.Value);
            updateFromSettings(app.CallingApp, micID, speakerID, round(app.RecTimeSlider.Value, 1));
            
            % Delete the dialog box
            UIFigureCloseRequest(app);
        end

        % Button pushed function: CancelButton
        function CancelButtonPushed(app, event)
            UIFigureCloseRequest(app);
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Color = [0.8 0.8 0.8];
            app.UIFigure.Position = [100 100 640 480];
            app.UIFigure.Name = 'MATLAB App';
            app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @UIFigureCloseRequest, true);

            % Create SettingsLabel
            app.SettingsLabel = uilabel(app.UIFigure);
            app.SettingsLabel.FontSize = 18;
            app.SettingsLabel.FontWeight = 'bold';
            app.SettingsLabel.Position = [296 421 77 22];
            app.SettingsLabel.Text = 'Settings';

            % Create RecTimesLabel
            app.RecTimesLabel = uilabel(app.UIFigure);
            app.RecTimesLabel.FontWeight = 'bold';
            app.RecTimesLabel.Position = [85 331 72 22];
            app.RecTimesLabel.Text = 'Rec Time, s';

            % Create SoundInputLabel
            app.SoundInputLabel = uilabel(app.UIFigure);
            app.SoundInputLabel.FontWeight = 'bold';
            app.SoundInputLabel.Position = [85 230 75 22];
            app.SoundInputLabel.Text = 'Sound Input';

            % Create SoundOutputLabel
            app.SoundOutputLabel = uilabel(app.UIFigure);
            app.SoundOutputLabel.FontWeight = 'bold';
            app.SoundOutputLabel.Position = [85 138 85 22];
            app.SoundOutputLabel.Text = 'Sound Output';

            % Create SaveButton
            app.SaveButton = uibutton(app.UIFigure, 'push');
            app.SaveButton.ButtonPushedFcn = createCallbackFcn(app, @SaveButtonPushed, true);
            app.SaveButton.BackgroundColor = [0 0 0];
            app.SaveButton.FontSize = 14;
            app.SaveButton.FontWeight = 'bold';
            app.SaveButton.FontColor = [1 1 1];
            app.SaveButton.Position = [85 56 100 24];
            app.SaveButton.Text = 'Save';

            % Create CancelButton
            app.CancelButton = uibutton(app.UIFigure, 'push');
            app.CancelButton.ButtonPushedFcn = createCallbackFcn(app, @CancelButtonPushed, true);
            app.CancelButton.BackgroundColor = [0 0 0];
            app.CancelButton.FontSize = 14;
            app.CancelButton.FontWeight = 'bold';
            app.CancelButton.FontColor = [1 1 1];
            app.CancelButton.Position = [459 56 100 24];
            app.CancelButton.Text = 'Cancel';

            % Create RecTimeSlider
            app.RecTimeSlider = uislider(app.UIFigure);
            app.RecTimeSlider.Limits = [0.3 2];
            app.RecTimeSlider.MajorTicks = [0.5 1 1.5 2];
            app.RecTimeSlider.MinorTicks = [0.3 0.32 0.34 0.36 0.38 0.4 0.42 0.44 0.46 0.48 0.5 0.52 0.54 0.56 0.58 0.6 0.62 0.64 0.66 0.68 0.7 0.72 0.74 0.76 0.78 0.8 0.82 0.84 0.86 0.88 0.9 0.92 0.94 0.96 0.98 1 1.02 1.04 1.06 1.08 1.1 1.12 1.14 1.16 1.18 1.2 1.22 1.24 1.26 1.28 1.3 1.32 1.34 1.36 1.38 1.4 1.42 1.44 1.46 1.48 1.5 1.52 1.54 1.56 1.58 1.6 1.62 1.64 1.66 1.68 1.7 1.72 1.74 1.76 1.78 1.8 1.82 1.84 1.86 1.88 1.9 1.92 1.94 1.96 1.98 2];
            app.RecTimeSlider.FontWeight = 'bold';
            app.RecTimeSlider.Position = [184 340 375 3];
            app.RecTimeSlider.Value = 0.5;

            % Create DropDown_SoundInput
            app.DropDown_SoundInput = uidropdown(app.UIFigure);
            app.DropDown_SoundInput.Items = {};
            app.DropDown_SoundInput.FontColor = [1 1 1];
            app.DropDown_SoundInput.BackgroundColor = [0 0 0];
            app.DropDown_SoundInput.Position = [184 230 375 22];
            app.DropDown_SoundInput.Value = {};

            % Create DropDown_SoundOutput
            app.DropDown_SoundOutput = uidropdown(app.UIFigure);
            app.DropDown_SoundOutput.Items = {};
            app.DropDown_SoundOutput.FontColor = [1 1 1];
            app.DropDown_SoundOutput.BackgroundColor = [0 0 0];
            app.DropDown_SoundOutput.Position = [184 138 375 22];
            app.DropDown_SoundOutput.Value = {};

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = SettingsApp_exported(varargin)

            runningApp = getRunningApp(app);

            % Check for running singleton app
            if isempty(runningApp)

                % Create UIFigure and components
                createComponents(app)

                % Register the app with App Designer
                registerApp(app, app.UIFigure)

                % Execute the startup function
                runStartupFcn(app, @(app)startupFcn(app, varargin{:}))
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
sca
clear;
clc;

try

    % ----------------------------- PARAMETERS ----------------------------- %

    % Durations
    practice_topic   = 'Hiking';
    
    isreal =  input("Is this real? (y/n)", 's');
    if isreal == 'y'
        trial_dur = 240; % trial duration in seconds
    elseif isreal == 'n'
        trial_dur = 10; % trial duration in seconds
    else
        error('y or n')
    end

    booklet_time = 4; % seconds for booklet ratings
    n_blocks = 6; 
    n_trials = 12;
    bx_trials = n_trials/n_blocks; 
    
    % Key codes for KbCheck()
    player_1  = 17; % numberpad Enter
    player_2  = 13; % left ctrl
    escape_k  = 27; % escape key
    skip_k    = 106; % *

    % Text Size
    relSz = 1;
    bigText = 100*relSz;
    instrText = 70*relSz;
    mediumText = 50*relSz;
    moderateText = 38*relSz;
    smallTextSize = 30*relSz;

    big_text_width = 32;
    intr_text_width = 70;
    
    % Text chunks:
    welcome1 = 'Welcome to this study on social communication.';
    welcome3 = 'Thank you for waiting!';
    welcome2 = 'In this study, you will hold conversations about different topics with your partner.';
    before_begin = 'Before beginning, we need to calibrate the equipment. For the next 2 minutes, please simply stay still and keep your gaze on the fixation cross.';
    rdy2cont = 'Press your button to continue.';
    instr3 = 'Each conversation will last 4 minutes. Please try to contribute equally to the conversation. In other words, aim to balance your speaking time with your partner''s, even if you don''t find the topic particularly interesting.';
    instr4 = 'Before each trial begins, you will see the topic for discussion along with a few optional prompts to guide you if you''re unsure what to say. These prompts are completely optional.';
    instr5 = ' Please hold off on starting the conversation until the topic text disappears, and do your best to keep the discussion on the assigned topic.';
    instr6 = 'At the end of each conversation, you will use your paper booklet to answer a few questions about your experience during that interaction.';
    instr7 = 'Your answers are completely private and will not be shared with your partner. Please take a moment to answer honestly and thoughtfully, and when you’re finished, return the booklet and pencil to their designated spot.';
    instr8 = 'Let''s listen to an example by two other speakers. Keep your eyes on the fixation cross and pay attention.';
    example_topic = 'X.';
    prctInstr = 'We''ll start with a practice trial to get you comfortable with the process.'; 
    rdy2start = 'Press your button when you''re ready to start';
    % optional_prompts = 'Optional discussion points:';
    about_to         = 'In this trial, you will talk about...';
    booklet_instr    = 'Please turn to your booklet now.'; 
    break_instr1     = 'Take a short break.'; 
    break_instr2     = 'When you''re ready to continue, press your button.';
    break_instr3     = 'Take a longer break. The researchers will check in on you now.';
    waiting          = 'Waiting';
    ready            = 'Ready';
    % practice_prompt1 = 'What''s one healthy food you actually enjoy eating?';
    % practice_prompt2 = 'What''s a small change you''ve made to your diet that made you feel better?';
    practice_trans1  = 'The researchers will now check in to see if you have any questions.';
    practice_trans2  = 'After that, the actual study trials will begin.';
    sil_null1        = 'For this trial, simply stay quiet and keep your gaze on the fixation cross (2 minutes).';
    list_null1       = 'In this trial, you will listen to a conversation by another pair of people. Keep your eyes on the fixation cross and pay attention';
    list_null2       = 'Keep your eyes on the fixation cross and pay attention.';
    bye1             = 'Thank you for participating!\nThe researchers will open the door in a moment.';


    % Get dyad's info
    dyad_num =  input("What is the dyad ID? ", 's');
    dyad_gen = input("What's the dyad gender? ", 's');  % initial prompt

    while ~strcmp(dyad_gen, 'f') && ~strcmp(dyad_gen, 'm')
        fprintf("Invalid input. Please enter 'f' or 'm'.\n");
        dyad_gen = input("What's the dyad gender? ", 's');  % prompt again
    end

    filename =  ['topic_lists/list' dyad_num '.csv'];
    dyad_info = readtable(filename);
    
    % Get screen info
    screens = Screen('Screens');
    screenNumber = max(screens);

    % Colors
    white = WhiteIndex(screenNumber);
    white2 = [200 200 200];
    black = BlackIndex(screenNumber);
    grey = GrayIndex(screenNumber);
    darkGrey = grey * 0.8;
    blue = [30 110 255];
    orange = [255, 165, 0];
    green = [80, 220, 100];

    % % % Misc set up
    % HideCursor();
    Screen('Preference', 'SkipSyncTests', 1);
    exit_status = 0;
    skip_status = 0;
    
    if dyad_gen == 'f'
        fold = 'wavs_f/';
        wavs_dir = dir('wavs_f');
    else
        fold = 'wavs_m/';
        wavs_dir = dir('wavs_m');
    end

    filesOnly = wavs_dir(~[wavs_dir.isdir]);
    fileNames = string({filesOnly.name});
    baselinewavs = fold + fileNames(randperm(length(fileNames)));

    SilCode1 = 50;
    SilCode2 = 60;
    ListCode1 = 70;
    ListCode2 = 80;
     
    % ----------------------------- INITIALIZE AUDIO ----------------------------- %
    InitializePsychSound(1);
    PsychPortAudio('Close'); %make sure all audio devices are closed
    PsychPortAudio('Verbosity', 12); %how much info to print out
    x  = PsychPortAudio('GetDevices'); % run to choose ID - usually many devices
    pahandle = PsychPortAudio('Open', 3, 1, 1, 48000, 2); %deviceID(speakers = 3(mme)/4(wasapi)), mode, latency mode,  freq, chann, buffersize, suddestedLate, select
    PsychPortAudio('RunMode', pahandle, 1);%
    
    fs = 44100;
    freq = 220; % Frequency in Hz
    duration = .5; % Duration in seconds
    t = 0:1/fs:duration;
    wave = 0.5 * sin(2 * pi * freq * t); % 50% amplitude
    audiostim = [wave; wave]; % Duplicate for stereo
    
    % Load and play the sound
    PsychPortAudio('FillBuffer', pahandle, audiostim);
    PsychPortAudio('Start', pahandle, 1, 0, 1);
    WaitSecs(duration);
    PsychPortAudio('Stop', pahandle, 1);
    
    % ------------------------- INITIALIZE SERIAL PORT ----------------------------- %
    
    TB = IOPort('OpenSerialPort', 'COM3', 'BaudRate=115200, DataBits=8');

    IOPort('Write', TB, uint8(92), 0);
    pause(0.01)
    IOPort('Write', TB, uint8(0), 0);

    triggerOn = uint8(128); % Trigger value to send
    triggerOff = uint8(0); % Reset trigger value
    triggerDuration = 0.04; % Duration in seconds 

    % ----------------------------- INITIALIZE SCREEN ----------------------------- %

    [window, windowRect] = PsychImaging('OpenWindow', screenNumber, black); 

    % Maximum priority level
    topPriorityLevel = MaxPriority(window);
    Priority(topPriorityLevel);
    
    height = windowRect(4);
    vpos1 = height/10;

    WaitSecs(1);
    
    % Get window parameters
    [screenXpixels, screenYpixels] = Screen('WindowSize', window);
    [xCenter, yCenter] = RectCenter(windowRect);
    wrapAt = windowRect(3) - 200; % Maximum text width

    % Get Word Size parameters and set Status position (really unnecessary, but just trying to make
    % everything perfectly symmetrical and soft-coded).
    border_dist = 300;
    
    Screen('TextSize', window, instrText);
    [nx, ny, textbounds1, wordbounds1] = DrawFormattedText(window, waiting, 300, vpos1*9.2, black);
    [nx, ny, textbounds2, wordbounds2] = DrawFormattedText(window, ready, 300, vpos1*9.2, black);
    Screen('Flip', window);
    
    waiting_px  = textbounds1(3) - textbounds1(1);
    waiting_pos = screenXpixels - border_dist - waiting_px;
    
    ready_px = textbounds2(3) - textbounds2(1);
    ready_pos = screenXpixels - border_dist - ready_px;

    % ----------------------------- WELCOME----------------------------- %

    for q = 1:3
        IOPort('Write', TB, triggerOn, 0); 
        WaitSecs(triggerDuration)
        IOPort('Write', TB, triggerOff, 0); % Deactivate trigger
        WaitSecs(.005)
    end
    
    % - - - - - - - - - - - - - - - - - - - - - - - - - - - Instructions 0 (Welcome)
    % Wait for participants to indicate they're ready
    p1_status = 0;
    p2_status = 0;

    while p1_status == 0 || p2_status == 0

        % Display instruction to take a short break
        Screen('TextSize', window, bigText);  Screen('TextStyle', window, 1);
        DrawFormattedText(window, welcome1, 'center', vpos1*2, white, big_text_width);
        Screen('TextSize', window, instrText); Screen('TextStyle', window, 0);
        DrawFormattedText(window, before_begin, 'center', vpos1*4.8, white2, intr_text_width);
        Screen('TextSize', window, mediumText); Screen('TextStyle', window, 2);
        DrawFormattedText(window, rdy2start, 'center', vpos1*8.5, grey, 55);

        [keyIsDown, ~, keyCode] = KbCheck();

        if keyIsDown
            key = find(keyCode, 1); % Get the first key code pressed
            % KbReleaseWait(); % avoid repeated detection
            if     key == player_1, p1_status = 1;
            elseif key == player_2, p2_status = 1;
            end
        end

        % Display participant status
        Screen('TextSize', window, instrText); Screen('TextStyle', window, 1);

        if p1_status == 0
            DrawFormattedText(window, waiting, 300, vpos1*9.2, orange);
        else
            DrawFormattedText(window, ready, 300, vpos1*9.2, green);
        end%if p1

        if p2_status == 0
            DrawFormattedText(window, waiting, waiting_pos, vpos1*9.2, orange);
        else
            DrawFormattedText(window, ready, ready_pos, vpos1*9.2, green);
        end%if p2

        Screen('Flip', window); % show all

    end %while 0 status
    WaitSecs(1.5);

    % - - - - - - - - - - - - - - - - - - - - - - - - - - - Baseline Silence 1


    % Show timer
    startTime = GetSecs();
    while GetSecs - startTime < 2.98
        timer = floor(3.99 - (GetSecs - startTime));

        Screen('TextSize', window, bigText*2);
        DrawFormattedText(window, [num2str(timer)], 'center', 'center', grey); % draw timer


        Screen('Flip', window);
    end

    Screen('Flip', window);
    WaitSecs(1);

    % send start Sync trigger
    for q = 1:2
        IOPort('Write', TB, triggerOn, 0); 
        WaitSecs(triggerDuration)
        IOPort('Write', TB, triggerOff, 0); % Deactivate trigger
        WaitSecs(.005)
    end

    % send start trigger
    IOPort('Write', TB, uint8(SilCode1+1), 0); 
    WaitSecs(triggerDuration)
    IOPort('Write', TB, triggerOff, 0); % Deactivate trigger

    % Show fixation cross
    fix = [xCenter-50 xCenter+50 xCenter xCenter; yCenter yCenter yCenter-50 yCenter+50];
    Screen('DrawLines', window, fix, 8, white);
    Screen('Flip', window);

    startTime = GetSecs();
    while GetSecs - startTime < trial_dur/2

        [keyIsDown, ~, keyCode] = KbCheck();

        if keyIsDown
            key = find(keyCode, 1); % Get the first key code pressed
            KbReleaseWait(); % avoid repeated detection
        end

        if  key == escape_k 
            exit_status = 1;
            break 
        end

    end

    if exit_status == 1
        sca;
        disp('Excape key pressed. Stopping the experiment.');
        return;
    end


    Screen('Flip', window);

    % send end trigger
    IOPort('Write', TB, uint8(SilCode2+1), 0); 
    WaitSecs(triggerDuration)
    IOPort('Write', TB, triggerOff, 0); % Deactivate trigger

    % send end Sync trigger
    IOPort('Write', TB, triggerOn, 0); % Send end
    WaitSecs(triggerDuration)
    IOPort('Write', TB, triggerOff, 0); % Deactivate trigger
    WaitSecs(.005)

    WaitSecs(4);

    % - - - - - - - - - - - - - - - - - - - - - - - - - - - Instructions 1 (Welcome)
    % Wait for participants to indicate they're ready
    p1_status = 0;
    p2_status = 0;

    while p1_status == 0 || p2_status == 0

        % Display instruction to take a short break
        Screen('TextSize', window, bigText);  Screen('TextStyle', window, 1);
        DrawFormattedText(window, welcome3, 'center', vpos1*2, white, big_text_width);
        Screen('TextSize', window, instrText); Screen('TextStyle', window, 0);
        DrawFormattedText(window, welcome2, 'center', vpos1*4.8, white2, intr_text_width);
        Screen('TextSize', window, mediumText); Screen('TextStyle', window, 2);
        DrawFormattedText(window, rdy2cont, 'center', vpos1*8.5, grey, 55);

        [keyIsDown, ~, keyCode] = KbCheck();

        if keyIsDown
            key = find(keyCode, 1); % Get the first key code pressed
            % KbReleaseWait(); % avoid repeated detection
            if     key == player_1, p1_status = 1;
            elseif key == player_2, p2_status = 1;
            end
        end

        % Display participant status
        Screen('TextSize', window, instrText); Screen('TextStyle', window, 1);

        if p1_status == 0
            DrawFormattedText(window, waiting, 300, vpos1*9.2, orange);
        else
            DrawFormattedText(window, ready, 300, vpos1*9.2, green);
        end%if p1

        if p2_status == 0
            DrawFormattedText(window, waiting, waiting_pos, vpos1*9.2, orange);
        else
            DrawFormattedText(window, ready, ready_pos, vpos1*9.2, green);
        end%if p2

        Screen('Flip', window); % show all

    end %while 0 status
    WaitSecs(1.5);

    % - - - - - - - - - - - - - - - - - - - - - - - - - - - Instructions 2 (Main Instructions)
    % Wait for participants to indicate they're ready
    p1_status = 0;
    p2_status = 0;

    while p1_status == 0 || p2_status == 0

        % Display instruction to take a short break
        Screen('TextSize', window, instrText);  Screen('TextStyle', window, 0);
        DrawFormattedText(window, instr3, 'center', vpos1*2.9, white, intr_text_width);
        % DrawFormattedText(window, instr4, 'center', vpos1*3.5, white, intr_text_width);
        DrawFormattedText(window, instr5, 'center', vpos1*5.3, white, intr_text_width);
        Screen('TextSize', window, mediumText); Screen('TextStyle', window, 2);
        DrawFormattedText(window, rdy2cont, 'center', vpos1*8.5, grey, 55);

        [keyIsDown, ~, keyCode] = KbCheck();

        if keyIsDown
            key = find(keyCode, 1); % Get the first key code pressed
            % KbReleaseWait(); % avoid repeated detection
            if     key == player_1, p1_status = 1;
            elseif key == player_2, p2_status = 1;
            end
        end

        % Display participant status
        Screen('TextSize', window, instrText); Screen('TextStyle', window, 1);

        if p1_status == 0
            DrawFormattedText(window, waiting, 300, vpos1*9.2, orange);
        else
            DrawFormattedText(window, ready, 300, vpos1*9.2, green);
        end%if p1

        if p2_status == 0
            DrawFormattedText(window, waiting, waiting_pos, vpos1*9.2, orange);
        else
            DrawFormattedText(window, ready, ready_pos, vpos1*9.2, green);
        end%if p2

        Screen('Flip', window); % show all

    end %while 0 status
    WaitSecs(1.5);

    % - - - - - - - - - - - - - - - - - - - - - - - - - - - Prepare for Example (Listening Baseline 1)
    % Wait for participants to indicate they're ready
    p1_status = 0;
    p2_status = 0;
        
    while p1_status == 0 || p2_status == 0

        % Display instruction 
        Screen('TextSize', window, instrText);  Screen('TextStyle', window, 1);
        DrawFormattedText(window, instr8, 'center', 'center', white, intr_text_width);
        % Screen('TextSize', window, bigText);  Screen('TextStyle', window, 0);
        % DrawFormattedText(window, example_topic, 'center', 'center', white, intr_text_width);
        Screen('TextSize', window, mediumText); Screen('TextStyle', window, 2);
        DrawFormattedText(window, rdy2start, 'center', vpos1*8.5, grey, 55);
        
        [keyIsDown, ~, keyCode] = KbCheck();

        if keyIsDown
            key = find(keyCode, 1); % Get the first key code pressed
            % KbReleaseWait(); % avoid repeated detection
            if     key == player_1, p1_status = 1;
            elseif key == player_2, p2_status = 1;
            end
        end

        % Display participant status
        Screen('TextSize', window, instrText); Screen('TextStyle', window, 1);

        if p1_status == 0
            DrawFormattedText(window, waiting, 300, vpos1*9.2, orange);
        else
            DrawFormattedText(window, ready, 300, vpos1*9.2, green);
        end%if p1

        if p2_status == 0
            DrawFormattedText(window, waiting, waiting_pos, vpos1*9.2, orange);
        else
            DrawFormattedText(window, ready, ready_pos, vpos1*9.2, green);
        end%if p2

        Screen('Flip', window); % show all

    end %while 0 status
    WaitSecs(1.5);

    % -------------------------------------------------------- Listening Baseline
    % audio stimulus onset
    wav_name = baselinewavs(1);
    wavfile = char(wav_name);
    [y, freq] = psychwavread(wavfile); % read file

    if freq < 47000
        y = resample(y, 48000, freq);
    end

    wavedata = y(:,1)'; % transpose audio data
    wavedata(2,:) = y(:,1)';
    PsychPortAudio('FillBuffer', pahandle, wavedata); % get the audio ready for playback

    % Show timer
    startTime = GetSecs();
    while GetSecs - startTime < 2.98
        timer = floor(3.99 - (GetSecs - startTime));

        Screen('TextSize', window, bigText*2);
        DrawFormattedText(window, [num2str(timer)], 'center', 'center', grey); % draw timer


        Screen('Flip', window);
    end
    
    Screen('Flip', window);
    WaitSecs(1);

    % send start Sync trigger
    for q = 1:2
        IOPort('Write', TB, triggerOn, 0); 
        WaitSecs(triggerDuration)
        IOPort('Write', TB, triggerOff, 0); % Deactivate trigger
        WaitSecs(.005)
    end
    
    % send start trigger
    IOPort('Write', TB, uint8(ListCode1+1), 0); 
    WaitSecs(triggerDuration)
    IOPort('Write', TB, triggerOff, 0); % Deactivate trigger

    % Show fixation cross
    fix = [xCenter-50 xCenter+50 xCenter xCenter; yCenter yCenter yCenter-50 yCenter+50];
    Screen('DrawLines', window, fix, 8, white);
    Screen('Flip', window);

    t1 = PsychPortAudio('Start', pahandle, 1, 0, 1); % play the audio
    
    startTime = GetSecs();
    while GetSecs - startTime < trial_dur/2
        
        [keyIsDown, ~, keyCode] = KbCheck();

        if keyIsDown
            key = find(keyCode, 1); % Get the first key code pressed
            KbReleaseWait(); % avoid repeated detection
        end

        if  key == escape_k 
            exit_status = 1;
            break 
        end
    
    end

    if exit_status == 1
        sca;
        disp('Excape key pressed. Stopping the experiment.');
        return;
    end
    

    [startTime, endPositionSecs, xruns, estStopTime] = PsychPortAudio('Stop', pahandle, 1); % Close audio
        
    Screen('Flip', window);

    % send end trigger
    IOPort('Write', TB, uint8(ListCode2+1), 0); 
    WaitSecs(triggerDuration)
    IOPort('Write', TB, triggerOff, 0); % Deactivate trigger

    % send end Sync trigger
    IOPort('Write', TB, triggerOn, 0); % Send trigger repeatedly
    WaitSecs(triggerDuration)
    IOPort('Write', TB, triggerOff, 0); % Deactivate trigger

    WaitSecs(2);

    % - - - - - - - - - - - - - - - - - - - - - - - - - - - Instructions 3 (Booklet Instructions)
    % Wait for participants to indicate they're ready
    p1_status = 0;
    p2_status = 0;
        
    while p1_status == 0 || p2_status == 0

        % Display instruction to take a short break
        Screen('TextSize', window, instrText);  Screen('TextStyle', window, 0);
        DrawFormattedText(window, instr6, 'center', vpos1*2.8, white, intr_text_width);
        DrawFormattedText(window, instr7, 'center', vpos1*5, white, intr_text_width);
        Screen('TextSize', window, mediumText); Screen('TextStyle', window, 2);
        DrawFormattedText(window, rdy2cont, 'center', vpos1*8.5, grey, 55);
        
        [keyIsDown, ~, keyCode] = KbCheck();

        if keyIsDown
            key = find(keyCode, 1); % Get the first key code pressed
            % KbReleaseWait(); % avoid repeated detection
            if     key == player_1, p1_status = 1;
            elseif key == player_2, p2_status = 1;
            end
        end

        % Display participant status
        Screen('TextSize', window, instrText); Screen('TextStyle', window, 1);

        if p1_status == 0
            DrawFormattedText(window, waiting, 300, vpos1*9.2, orange);
        else
            DrawFormattedText(window, ready, 300, vpos1*9.2, green);
        end%if p1

        if p2_status == 0
            DrawFormattedText(window, waiting, waiting_pos, vpos1*9.2, orange);
        else
            DrawFormattedText(window, ready, ready_pos, vpos1*9.2, green);
        end%if p2

        Screen('Flip', window); % show all

    end %while 0 status
    WaitSecs(1.5);


    % - - - - - - - - - - - - - - - - - - - - - - - - - - - Instructions 4 (Ready to practice)
    % Wait for participants to indicate they're ready
    p1_status = 0;
    p2_status = 0;
        
    while p1_status == 0 || p2_status == 0

        % Display instruction to take a short break
        Screen('TextSize', window, instrText);  Screen('TextStyle', window, 1);
        DrawFormattedText(window, prctInstr, 'center', vpos1*4.7, white, intr_text_width);
        Screen('TextSize', window, mediumText); Screen('TextStyle', window, 2);
        DrawFormattedText(window, rdy2start, 'center', vpos1*8.5, grey, 55);
        
        [keyIsDown, ~, keyCode] = KbCheck();

        if keyIsDown
            key = find(keyCode, 1); % Get the first key code pressed
            % KbReleaseWait(); % avoid repeated detection
            if     key == player_1, p1_status = 1;
            elseif key == player_2, p2_status = 1;
            elseif key == escape_k, exit_status = 1;
            end
        end
        

        % Display participant status
        Screen('TextSize', window, instrText); Screen('TextStyle', window, 1);

        if p1_status == 0
            DrawFormattedText(window, waiting, 300, vpos1*9.2, orange);
        else
            DrawFormattedText(window, ready, 300, vpos1*9.2, green);
        end%if p1

        if p2_status == 0
            DrawFormattedText(window, waiting, waiting_pos, vpos1*9.2, orange);
        else
            DrawFormattedText(window, ready, ready_pos, vpos1*9.2, green);
        end%if p2

        Screen('Flip', window); % show all

    end %while 0 status
    WaitSecs(2);

    if exit_status == 1
        sca;
        disp('Excape key pressed. Stopping the experiment.');
        return;
    end


    % ----------------------------- PRACTICE TRIAL ----------------------------- %

    p1_status = 0;
    p2_status = 0;
        
    while p1_status == 0 || p2_status == 0

        Screen('TextSize', window, bigText); 
        Screen('TextStyle', window, 1);
        DrawFormattedText(window, practice_topic, 'center', 'center', white); 
        
        Screen('TextSize', window, mediumText); 
        Screen('TextStyle', window, 2);
        DrawFormattedText(window, about_to, 50, vpos1, grey);
        % DrawFormattedText(window, optional_prompts, 50, vpos1*2.6, grey); 

        Screen('TextSize', window, instrText); 
        Screen('TextStyle', window, 0);
        % DrawFormattedText(window, practice_prompt1, 'center', vpos1*3.7, white, 55);
        % DrawFormattedText(window, practice_prompt2, 'center', vpos1*5.9, white, 55);
        
        Screen('TextSize', window, mediumText); Screen('TextStyle', window, 2);
        DrawFormattedText(window, rdy2start, 'center', vpos1*8.5, grey, 55);
        
        [keyIsDown, ~, keyCode] = KbCheck();

        if keyIsDown
            key = find(keyCode, 1); % Get the first key code pressed
            % KbReleaseWait(); % avoid repeated detection
            if     key == player_1, p1_status = 1;
            elseif key == player_2, p2_status = 1;
            end
        end

        % Display participant status
        Screen('TextSize', window, instrText); Screen('TextStyle', window, 1);

        if p1_status == 0
            DrawFormattedText(window, waiting, 300, vpos1*9.2, orange);
        else
            DrawFormattedText(window, ready, 300, vpos1*9.2, green);
        end%if p1

        if p2_status == 0
            DrawFormattedText(window, waiting, waiting_pos, vpos1*9.2, orange);
        else
            DrawFormattedText(window, ready, ready_pos, vpos1*9.2, green);
        end%if p2

        Screen('Flip', window); % show all

    end
    
    WaitSecs(2);
    
    % Show timer
    startTime = GetSecs();
    while GetSecs - startTime < 2.98
        timer = floor(3.99 - (GetSecs - startTime));

        Screen('TextSize', window, bigText*2);
        DrawFormattedText(window, [num2str(timer)], 'center', 'center', grey); % draw timer


        Screen('Flip', window);
    end
    
    Screen('Flip', window);
    WaitSecs(1);
    
    % send trigger
    for q = 1:3
        IOPort('Write', TB, triggerOn, 0); 
        WaitSecs(triggerDuration)
        IOPort('Write', TB, triggerOff, 0); % Deactivate trigger
        WaitSecs(.005)
    end

    IOPort('Write', TB, uint8(90), 0); 
    WaitSecs(triggerDuration)
    IOPort('Write', TB, triggerOff, 0); % Deactivate trigger

    % Show fixation cross
    fix = [xCenter-50 xCenter+50 xCenter xCenter; yCenter yCenter yCenter-50 yCenter+50];
    Screen('DrawLines', window, fix, 8, white);
    Screen('Flip', window);
    
    startTime = GetSecs();
    while GetSecs - startTime < trial_dur-(trial_dur/12)
        
        [keyIsDown, ~, keyCode] = KbCheck();

        if keyIsDown
            key = find(keyCode, 1); % Get the first key code pressed
            KbReleaseWait(); % avoid repeated detection
        end

        if  key == escape_k 
            exit_status = 1;
            break
        elseif key == skip_k
            skip_status = 1;
            break
        end
    end
    
    if exit_status == 1
                sca;
                disp('Excape key pressed. Stopping the experiment.');
                return;
    end
    
    if skip_status == 0
        % Change color of fixation cross
        Screen('DrawLines', window, fix, 8, blue);
        Screen('Flip', window);
    
        WaitSecs(trial_dur/12);
            
        Screen('Flip', window);

        IOPort('Write', TB, uint8(90), 0); 
        WaitSecs(triggerDuration)
        IOPort('Write', TB, triggerOff, 0); % Deactivate trigger
        
        % send end trigger
        IOPort('Write', TB, triggerOn, 0); 
        WaitSecs(triggerDuration)
        IOPort('Write', TB, triggerOff, 0); % Deactivate trigger
        WaitSecs(.005)
    
        WaitSecs(4);
    
        % Display instruction to fill in the ratings for the current trial
        Screen('TextSize', window, bigText); 
        Screen('TextStyle', window, 1);
        DrawFormattedText(window, booklet_instr, 'center', 'center', white);
        DrawFormattedText(window, '(Practice Conversation)', 'center', vpos1*7.2, grey);
        Screen('Flip', window);
    
        WaitSecs(booklet_time);
    end

    % % % %  Ask them if ready for actual trials

    % Wait for participants to indicate they're ready
    p1_status = 0;
    p2_status = 0;
        
    while p1_status == 0 || p2_status == 0

        % Display instruction to take a short break
        Screen('TextSize', window, instrText);
        DrawFormattedText(window, practice_trans1, 'center', vpos1*3, white, intr_text_width);
        DrawFormattedText(window, practice_trans2, 'center', vpos1*5, grey, intr_text_width);

        Screen('TextSize', window, mediumText); Screen('TextStyle', window, 2);
        DrawFormattedText(window, rdy2start, 'center', vpos1*8.5, grey, 55);
        
        [keyIsDown, ~, keyCode] = KbCheck();

        if keyIsDown
            key = find(keyCode, 1); % Get the first key code pressed
            % KbReleaseWait(); % avoid repeated detection
            if     key == player_1, p1_status = 1;
            elseif key == player_2, p2_status = 1;
            end
        end

        % Display participant status
        Screen('TextSize', window, instrText); Screen('TextStyle', window, 1);

        if p1_status == 0
            DrawFormattedText(window, waiting, 300, vpos1*9.2, orange);
        else
            DrawFormattedText(window, ready, 300, vpos1*9.2, green);
        end%if p1

        if p2_status == 0
            DrawFormattedText(window, waiting, waiting_pos, vpos1*9.2, orange);
        else
            DrawFormattedText(window, ready, ready_pos, vpos1*9.2, green);
        end%if p2

        Screen('Flip', window); % show all

    end %while 0 status

    WaitSecs(2); Screen('Flip', window);
    WaitSecs(2);

    % ----------------------------- MAIN TASK !----------------------------- %

    % randomize block order
    block_order = randperm(n_blocks);

    % total trial count
    trial_count = 0;
    block_count = 0;
    null_count = 1;
    % eng_count = 0;
    % neu_count = 0;

    for jn = 1:n_blocks % Blocks
        
        disp(['# - - - - - - - - - - - STARTING BLOCK ', num2str(jn), '/6. - - - - - - - - -  - - #']);
        
        % Extract block information
        j = block_order(jn);
        block_info = dyad_info(dyad_info.block == j,:);
        
        % Randomize trial order
        trial_order = randperm(bx_trials);

        block_count = block_count + 1;

        for id = 1:bx_trials % Trials

            trial_count = trial_count + 1;
            
            % Extract trial information
            i = trial_order(id);
            topic = block_info.topic{i};
            topicType = convertCharsToStrings(block_info.interest_level{i});
            
            if topicType == "high"
                topicCode1 = 10;
                topicCode2 = 20;
            else
                topicCode1 = 30;
                topicCode2 = 40;
            end

            prompt1 = block_info.prompt1{i};
            prompt2 = block_info.prompt2{i};

            % Initialize text presentation

            p1_status = 0;
            p2_status = 0;
                
            while p1_status == 0 || p2_status == 0

                Screen('TextSize', window, bigText); 
                Screen('TextStyle', window, 1);
                DrawFormattedText(window, topic, 'center', 'center', white); 
                
                Screen('TextSize', window, mediumText); 
                Screen('TextStyle', window, 2);
                % DrawFormattedText(window, optional_prompts, 50, vpos1*2.6, grey); 
                DrawFormattedText(window, about_to, 50, vpos1, grey);
    
                % Screen('TextSize', window, instrText); 
                % Screen('TextStyle', window, 0);
                % DrawFormattedText(window, prompt1, 'center', vpos1*3.7, white, 55);
                % DrawFormattedText(window, prompt2, 'center', vpos1*5.9, white, 55);
                
                Screen('TextSize', window, mediumText); Screen('TextStyle', window, 2);
                DrawFormattedText(window, rdy2start, 'center', vpos1*8.5, grey, 55);
                
                [keyIsDown, ~, keyCode] = KbCheck();

                if keyIsDown
                    key = find(keyCode, 1); % Get the first key code pressed
                    % KbReleaseWait(); % avoid repeated detection
                    if     key == player_1, p1_status = 1;
                    elseif key == player_2, p2_status = 1;
                    end
                end
        
                % Display participant status
                Screen('TextSize', window, instrText); Screen('TextStyle', window, 1);
        
                if p1_status == 0
                    DrawFormattedText(window, waiting, 300, vpos1*9.2, orange);
                else
                    DrawFormattedText(window, ready, 300, vpos1*9.2, green);
                end%if p1
        
                if p2_status == 0
                    DrawFormattedText(window, waiting, waiting_pos, vpos1*9.2, orange);
                else
                    DrawFormattedText(window, ready, ready_pos, vpos1*9.2, green);
                end%if p2
        
                Screen('Flip', window); % show all

            end
            
            WaitSecs(2);
            
            % Show timer
            startTime = GetSecs();
            while GetSecs - startTime < 2.98
                timer = floor(3.99 - (GetSecs - startTime));
    
                Screen('TextSize', window, bigText*2);
                DrawFormattedText(window, [num2str(timer)], 'center', 'center', grey); % draw timer
    
    
                Screen('Flip', window);
            end
            
            Screen('Flip', window);
            WaitSecs(1);
            
            % send start trigger
            for q = 1:2
                IOPort('Write', TB, triggerOn, 0); 
                WaitSecs(triggerDuration)
                IOPort('Write', TB, triggerOff, 0); % Deactivate trigger
                WaitSecs(.005)
            end

            IOPort('Write', TB, uint8(topicCode1 + block_count), 0); 
            WaitSecs(triggerDuration)
            IOPort('Write', TB, triggerOff, 0); % Deactivate trigger

            % Show fixation cross
            fix = [xCenter-50 xCenter+50 xCenter xCenter; yCenter yCenter yCenter-50 yCenter+50];
            Screen('DrawLines', window, fix, 8, white);
            Screen('Flip', window);
            
            startTime = GetSecs();
            while GetSecs - startTime < trial_dur-(trial_dur/12)
                
                [keyIsDown, ~, keyCode] = KbCheck();
        
                if keyIsDown
                    key = find(keyCode, 1); % Get the first key code pressed
                    KbReleaseWait(); % avoid repeated detection
                end
        
                if  key == escape_k 
                    exit_status = 1;
                    break 
                end
            
            end

            if exit_status == 1
                sca;
                disp('Excape key pressed. Stopping the experiment.');
                return;
            end
            
            % Change color of fixation cross
            Screen('DrawLines', window, fix, 8, blue);
            Screen('Flip', window);

            WaitSecs(trial_dur/12);
                
            Screen('Flip', window);
            
            % send end trigger
            IOPort('Write', TB, uint8(topicCode2 + block_count), 0); 
            WaitSecs(triggerDuration)
            IOPort('Write', TB, triggerOff, 0); % Deactivate trigger

            % send end Sync trigger
            IOPort('Write', TB, triggerOn, 0); 
            WaitSecs(triggerDuration)
            IOPort('Write', TB, triggerOff, 0); 
            
            % Display instruction to fill in the ratings for the current trial
            Screen('TextSize', window, bigText); 
            Screen('TextStyle', window, 1);
            DrawFormattedText(window, booklet_instr, 'center', 'center', white);
            DrawFormattedText(window, ['(Conversation ' num2str(trial_count) ')'], 'center', vpos1*7.2, grey);
            Screen('Flip', window);
    
            WaitSecs(booklet_time);
                        
            % if id < bx_trials % If the block has not ended
            
            if jn ~= 3
                % ------- Short break ------- %
    
                % Wait for participants to indicate they're ready
                p1_status = 0;
                p2_status = 0;
                    
                while p1_status == 0 || p2_status == 0
    
                    % Display instruction to take a short break
                    DrawFormattedText(window, break_instr1, 'center', vpos1*3, white, 30);
                    Screen('TextSize', window, instrText); 
                    DrawFormattedText(window, break_instr2, 'center', vpos1*5, grey);
                    
                    [keyIsDown, ~, keyCode] = KbCheck();
        
                    if keyIsDown
                        key = find(keyCode, 1); % Get the first key code pressed
                        % KbReleaseWait(); % avoid repeated detection
                        if     key == player_1, p1_status = 1;
                        elseif key == player_2, p2_status = 1;
                        end
                    end
    
                    % Display participant status
                    if p1_status == 0
                        DrawFormattedText(window, waiting, 300, vpos1*9.2, orange);
                    else
                        DrawFormattedText(window, ready, 300, vpos1*9.2, green);
                    end%if p1
    
                    if p2_status == 0
                        DrawFormattedText(window, waiting, waiting_pos, vpos1*9.2, orange);
                    else
                        DrawFormattedText(window, ready, ready_pos, vpos1*9.2, green);
                    end%if p2
    
                    Screen('Flip', window); % show all
    
                end %while 0 status
                
                WaitSecs(2); Screen('Flip', window);
                WaitSecs(2);
    
                % end %if in-block
            end % end if block 3

        end

        % - - - - - - - LONGER BREAK IF BLOCK 3 - - - - - - - - - - - %

        if block_count == 3
            
            p1_status = 0;
            p2_status = 0;
                
            while p1_status == 0 || p2_status == 0
    
                DrawFormattedText(window, break_instr3, 'center', vpos1*3, white, 55);
                Screen('TextSize', window, instrText); 
                DrawFormattedText(window, break_instr2, 'center', vpos1*5, grey);
                
                [keyIsDown, ~, keyCode] = KbCheck();
    
                if keyIsDown
                    key = find(keyCode, 1); % Get the first key code pressed
                    % KbReleaseWait(); % avoid repeated detection
                    if     key == player_1, p1_status = 1;
                    elseif key == player_2, p2_status = 1;
                    end
                end
    
                % Display participant status
                if p1_status == 0
                    DrawFormattedText(window, waiting, 300, vpos1*9.2, orange);
                else
                    DrawFormattedText(window, ready, 300, vpos1*9.2, green);
                end%if p1
    
                if p2_status == 0
                    DrawFormattedText(window, waiting, waiting_pos, vpos1*9.2, orange);
                else
                    DrawFormattedText(window, ready, ready_pos, vpos1*9.2, green);
                end%if p2
    
                Screen('Flip', window); % show all
    
            end %while 0 status
            
            WaitSecs(2); Screen('Flip', window);
            WaitSecs(2);

            continue

        end

        % - - - - - - - - - - - - - - SILENCE AND LISTENING - - - - - %

        % --------------------------------------------------------Silence Baseline
        
        null_count = null_count + 1;

        p1_status = 0;
        p2_status = 0;
            
        while p1_status == 0 || p2_status == 0
    
            % Display instruction to start Silence
            Screen('TextSize', window, instrText);  Screen('TextStyle', window, 0);
            DrawFormattedText(window, sil_null1, 'center', vpos1*4, white, intr_text_width);
            Screen('TextSize', window, mediumText); Screen('TextStyle', window, 2);
            DrawFormattedText(window, rdy2start, 'center', vpos1*8.5, grey, 55);
            
            [keyIsDown, ~, keyCode] = KbCheck();
    
            if keyIsDown
                key = find(keyCode, 1); % Get the first key code pressed
                % KbReleaseWait(); % avoid repeated detection
                if     key == player_1, p1_status = 1;
                elseif key == player_2, p2_status = 1;
                end
            end
    
            % Display participant status
            Screen('TextSize', window, instrText); Screen('TextStyle', window, 1);
    
            if p1_status == 0
                DrawFormattedText(window, waiting, 300, vpos1*9.2, orange);
            else
                DrawFormattedText(window, ready, 300, vpos1*9.2, green);
            end%if p1
    
            if p2_status == 0
                DrawFormattedText(window, waiting, waiting_pos, vpos1*9.2, orange);
            else
                DrawFormattedText(window, ready, ready_pos, vpos1*9.2, green);
            end%if p2
    
            Screen('Flip', window); % show all
    
        end %while 0 status
        WaitSecs(1.5);

        % Show timer
        startTime = GetSecs();
        while GetSecs - startTime < 2.98
            timer = floor(3.99 - (GetSecs - startTime));

            Screen('TextSize', window, bigText*2);
            DrawFormattedText(window, [num2str(timer)], 'center', 'center', grey); % draw timer


            Screen('Flip', window);
        end
        
        Screen('Flip', window);
        WaitSecs(1);

        % send start Sync trigger
        for q = 1:2
            IOPort('Write', TB, triggerOn, 0); 
            WaitSecs(triggerDuration)
            IOPort('Write', TB, triggerOff, 0); % Deactivate trigger
            WaitSecs(.005)
        end
        
        % send start trigger
        IOPort('Write', TB, uint8(SilCode1 + null_count), 0); 
        WaitSecs(triggerDuration)
        IOPort('Write', TB, triggerOff, 0); % Deactivate trigger

        % Show fixation cross
        fix = [xCenter-50 xCenter+50 xCenter xCenter; yCenter yCenter yCenter-50 yCenter+50];
        Screen('DrawLines', window, fix, 8, white);
        Screen('Flip', window);
        
        startTime = GetSecs();
        while GetSecs - startTime < trial_dur/2
            
            [keyIsDown, ~, keyCode] = KbCheck();
    
            if keyIsDown
                key = find(keyCode, 1); % Get the first key code pressed
                KbReleaseWait(); % avoid repeated detection
            end
    
            if  key == escape_k 
                exit_status = 1;
                break 
            end
        
        end

        if exit_status == 1
            sca;
            disp('Excape key pressed. Stopping the experiment.');
            return;
        end
            
        Screen('Flip', window);
        
        % send end trigger
        IOPort('Write', TB, uint8(SilCode2 + null_count), 0); 
        WaitSecs(triggerDuration)
        IOPort('Write', TB, triggerOff, 0); % Deactivate trigger

        % send end Sync trigger
        IOPort('Write', TB, triggerOn, 0); % Send trigger repeatedly
        WaitSecs(triggerDuration)
        IOPort('Write', TB, triggerOff, 0); % Deactivate trigger
        WaitSecs(.005)

        WaitSecs(4);
        

        % % % % % % % % % Display instruction to take a short break
        p1_status = 0;
        p2_status = 0;
            
        while p1_status == 0 || p2_status == 0

            DrawFormattedText(window, break_instr1, 'center', vpos1*3, white, 30);
            Screen('TextSize', window, instrText); 
            DrawFormattedText(window, break_instr2, 'center', vpos1*5, grey);
            
            [keyIsDown, ~, keyCode] = KbCheck();

            if keyIsDown
                key = find(keyCode, 1); % Get the first key code pressed
                % KbReleaseWait(); % avoid repeated detection
                if     key == player_1, p1_status = 1;
                elseif key == player_2, p2_status = 1;
                end
            end

            % Display participant status
            if p1_status == 0
                DrawFormattedText(window, waiting, 300, vpos1*9.2, orange);
            else
                DrawFormattedText(window, ready, 300, vpos1*9.2, green);
            end%if p1

            if p2_status == 0
                DrawFormattedText(window, waiting, waiting_pos, vpos1*9.2, orange);
            else
                DrawFormattedText(window, ready, ready_pos, vpos1*9.2, green);
            end%if p2

            Screen('Flip', window); % show all

        end %while 0 status
        
        WaitSecs(2); Screen('Flip', window);
        WaitSecs(2);

        % -------------------------------------------------------- Listening Baseline
        % audio stimulus onset
        wav_name = baselinewavs(null_count);
        wavfile = char(wav_name);
        [y, freq] = psychwavread(wavfile); % read file

        if freq < 47000
            y = resample(y, 48000, freq);
        end

        wavedata = y(:,1)'; % transpose audio data
        wavedata(2,:) = y(:,1)';
        PsychPortAudio('FillBuffer', pahandle, wavedata); % get the audio ready for playback

        p1_status = 0;
        p2_status = 0;
            
        while p1_status == 0 || p2_status == 0
    
            % Ready to start listening
            Screen('TextSize', window, instrText);  Screen('TextStyle', window, 0);
            DrawFormattedText(window, list_null1, 'center', vpos1*4, white, intr_text_width);
            Screen('TextSize', window, mediumText); Screen('TextStyle', window, 2);
            DrawFormattedText(window, rdy2start, 'center', vpos1*8.5, grey, 55);
            
            [keyIsDown, ~, keyCode] = KbCheck();
    
            if keyIsDown
                key = find(keyCode, 1); % Get the first key code pressed
                % KbReleaseWait(); % avoid repeated detection
                if     key == player_1, p1_status = 1;
                elseif key == player_2, p2_status = 1;
                end
            end
    
            % Display participant status
            Screen('TextSize', window, instrText); Screen('TextStyle', window, 1);
    
            if p1_status == 0
                DrawFormattedText(window, waiting, 300, vpos1*9.2, orange);
            else
                DrawFormattedText(window, ready, 300, vpos1*9.2, green);
            end%if p1
    
            if p2_status == 0
                DrawFormattedText(window, waiting, waiting_pos, vpos1*9.2, orange);
            else
                DrawFormattedText(window, ready, ready_pos, vpos1*9.2, green);
            end%if p2
    
            Screen('Flip', window); % show all
    
        end %while 0 status
        WaitSecs(1.5);

        % Show timer
        startTime = GetSecs();
        while GetSecs - startTime < 2.98
            timer = floor(3.99 - (GetSecs - startTime));

            Screen('TextSize', window, bigText*2);
            DrawFormattedText(window, [num2str(timer)], 'center', 'center', grey); % draw timer


            Screen('Flip', window);
        end
        
        Screen('Flip', window);
        WaitSecs(1);

        % send start Sync trigger
        for q = 1:2
            IOPort('Write', TB, triggerOn, 0); 
            WaitSecs(triggerDuration)
            IOPort('Write', TB, triggerOff, 0); % Deactivate trigger
            WaitSecs(.005)
        end
        
        % send start trigger
        IOPort('Write', TB, uint8(ListCode1 + null_count), 0); 
        WaitSecs(triggerDuration)
        IOPort('Write', TB, triggerOff, 0); % Deactivate trigger

        % Show fixation cross
        fix = [xCenter-50 xCenter+50 xCenter xCenter; yCenter yCenter yCenter-50 yCenter+50];
        Screen('DrawLines', window, fix, 8, white);
        Screen('Flip', window);

        t1 = PsychPortAudio('Start', pahandle, 1, 0, 1); % play the audio
        
        startTime = GetSecs();
        while GetSecs - startTime < trial_dur/2
            
            [keyIsDown, ~, keyCode] = KbCheck();
    
            if keyIsDown
                key = find(keyCode, 1); % Get the first key code pressed
                KbReleaseWait(); % avoid repeated detection
            end
    
            if  key == escape_k 
                exit_status = 1;
                break 
            end
        
        end

        if exit_status == 1
            sca;
            disp('Excape key pressed. Stopping the experiment.');
            return;
        end
        

        [startTime, endPositionSecs, xruns, estStopTime] = PsychPortAudio('Stop', pahandle, 1); % Close audio
            
        Screen('Flip', window);


        % send end trigger
        IOPort('Write', TB, uint8(ListCode2 + null_count), 0); 
        WaitSecs(triggerDuration)
        IOPort('Write', TB, triggerOff, 0); % Deactivate trigger

        % send end Sync trigger
        IOPort('Write', TB, triggerOn, 0); % Send trigger 
        WaitSecs(triggerDuration)
        IOPort('Write', TB, triggerOff, 0); % Deactivate trigger

        WaitSecs(4);


        % % % % % % % % % Display instruction to take a short break
        p1_status = 0;
        p2_status = 0;
            
        while p1_status == 0 || p2_status == 0

            DrawFormattedText(window, break_instr1, 'center', vpos1*3, white, 30);
            Screen('TextSize', window, instrText); 
            DrawFormattedText(window, break_instr2, 'center', vpos1*5, grey);
            
            [keyIsDown, ~, keyCode] = KbCheck();

            if keyIsDown
                key = find(keyCode, 1); % Get the first key code pressed
                % KbReleaseWait(); % avoid repeated detection
                if     key == player_1, p1_status = 1;
                elseif key == player_2, p2_status = 1;
                end
            end

            % Display participant status
            if p1_status == 0
                DrawFormattedText(window, waiting, 300, vpos1*9.2, orange);
            else
                DrawFormattedText(window, ready, 300, vpos1*9.2, green);
            end%if p1

            if p2_status == 0
                DrawFormattedText(window, waiting, waiting_pos, vpos1*9.2, orange);
            else
                DrawFormattedText(window, ready, ready_pos, vpos1*9.2, green);
            end%if p2

            Screen('Flip', window); % show all

        end %while 0 status
        
        WaitSecs(2); Screen('Flip', window);
        WaitSecs(2);

    end

    Screen('TextSize', window, bigText);  Screen('TextStyle', window, 1);
    DrawFormattedText(window, bye1, 'center', 'center', white, big_text_width);
    Screen('Flip', window);
    WaitSecs(2);
    KbWait();
    disp('# - - - - - - - - - - - - - - - - - EXPERIMENT FINALIZED. - - - - - - - - - - - - - - - - - - - #')

catch me
end

PsychPortAudio('Close', pahandle);
IOPort('Close', TB);
sca;

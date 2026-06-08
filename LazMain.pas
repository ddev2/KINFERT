{$I Defines.pas}
unit LazMain;

{$mode objfpc}{$H+}

interface

uses
	{$IFDEF UNIX}
	cthreads,
	{$ENDIF}
	{$IFDEF WINDOWS}
	Windows,
	{$ENDIF}
	Interfaces, // this includes the LCL widgetset
	Forms, Math,
	Classes, SysUtils, Controls, Graphics, Dialogs, LCLType, StdCtrls, Menus,
	ExtCtrls, Utilities, LResources, ComCtrls, LazConfig, LazGraph, LazUtiles;

const
	kEndThreadMessage = 'KinFert main thread ended';
	
type
	pAsyncData = ^AsyncData;
    AsyncData = record
		Text: string;
		outFile: TFileType;
		perCent: double;
	end;

	TKinFertMainThread = class(TThread)
	private
		fStatusText : string;
		FAFinished: boolean;
		
		procedure ShowStatus;

	public
		Constructor Create(CreateSuspended : boolean);
		procedure Execute; override;
		property AFinished: boolean read FAFinished write FAFinished;
	end;
		
	{ TKinFertForm }
	TKinFertForm = class(TForm)
		CED: TImage;
		ZipLab: TLabel;
		ProgressBar: TProgressBar;
		SaveOutputDialog: TSaveDialog;
		SaveOutput: TButton;
		errorShape: TShape;
		errorStatusLab: TLabel;
		MainMenu1: TMainMenu;
		FileMenu: TMenuItem;
		FileMenuSep: TMenuItem;
		FileOpenMenu: TMenuItem;
		FileQuitMenu: TMenuItem;
		UtilesBtn: TButton;
		VersionString: TLabel;
		Reset_nRuns: TButton;
		GraphsBtn: TButton;
		QuitBtn: TButton;
		Log: TMemo;
		status: TLabel;
		createConfigFile: TButton;
		runSimul: TButton;
		OutputDirButton: TButton;
		ChooseConfigButton: TButton;
		ConfigFileName: TLabel;
		OutputDirName: TLabel;
		OpenConfigDialog: TOpenDialog;
		OutputDirectoryDialog: TSelectDirectoryDialog;
		// edit or read config
		procedure createConfigFileClick(Sender: TObject);
		procedure ChooseConfigButtonClick(Sender: TObject);
		procedure OutputDirButtonClick(Sender: TObject);
		procedure FileQuitMenuClick(Sender: TObject);
		procedure GraphsBtnClick(Sender: TObject);
		procedure FileOpenMenuClick(Sender: TObject);
		procedure QuitBtnClick(Sender: TObject);
		procedure Reset_nRunsClick(Sender: TObject);
		procedure runSimulClick(Sender: TObject);
		procedure endSimulation(Sender: TObject);
		procedure ZipProgressHandler(Sender: TObject; const percent: Double);
		procedure FormCreate(Sender: TObject);
		procedure SaveOutputClick(Sender: TObject);
		procedure UtilesBtnClick(Sender: TObject);
		procedure FormResize(Sender: TObject);
		procedure MainThreadMessage(Sender: TObject; s: string);

	private
		myBufferStr: TStringList;
		myLine: string;
		myUpdateCount: integer;
		mainThread: TKinFertMainThread;
		memoWriting: boolean;

	public
		constructor Create(AOwner: TComponent); override;
		destructor Destroy; override;
		procedure ReadStdPath (fileName: string; var path: string);
		procedure setOutputPath(path:string);
		procedure WriteStdPath (fileName, path: string);
        procedure saveLog (fileNameWithPath: string);
		procedure ClearLog;
        procedure myCloseFiles(Data: PtrInt);
		procedure writeExec(pData: pAsyncData);
		procedure writeLnExec(pData: pAsyncData);
		procedure AsyncProgressBar(Data: PtrInt);
		procedure AsyncWrite(Data: PtrInt);
		procedure AsyncWriteLn(Data: PtrInt);
		procedure myWrite(outFile: TFileType; s: string);
		procedure myWriteLn(outFile: TFileType; s: string);
		procedure doMemoWrite (s: string);
		procedure AsyncMemoWrite(Data: PtrInt);
		procedure doMemoWriteLn (s: string);
		procedure MemoWriteLnExec(s: string);
		procedure MemoWriteExec(s: string);
		procedure AsyncMemoWriteLn(Data: PtrInt);
		procedure AsyncFlushString;
		procedure FlushString(Data: PtrInt);
		procedure statusCaption(s: string);
		procedure statusCaptionExec(s: string);
		procedure AsyncStatusCaption(Data: PtrInt);
		
	public
		simulationRan: boolean;
	end;

	var
		KinFertForm: TKinFertForm;

implementation
{$R *.lfm}
uses
	Declarations, ReadCmdFileUnit, {$IFDEF VerboseProfiler}Profiler,{$ENDIF} Init;

var
	deltaLogWidth, deltaLogHeight: longint;

 	function MessageBoxTwoChoices (option1, option2: PChar): boolean;
	var 
		Reply, BoxStyle: Integer;
	begin
		BoxStyle := MB_ICONQUESTION + MB_YESNO;
		Reply := Application.MessageBox(option1, option2, BoxStyle);
		result := (Reply = IDYES);
	end;	


{ TKinFertForm }

constructor TKinFertForm.Create(AOwner: TComponent);
begin
	inherited;
	myBufferStr := TStringList.Create;
	myLine := '';
	myUpdateCount := 0;
	gMainPathToResult := '';
	gPathToResult := '';
	Init_runs ();
	defaultConfigFile;
	if application.hasOption('GUI') then
	begin
		gRunFromIDE := True;
	end;
	Self.Constraints.MinWidth := self.Width;
	Self.Constraints.MinHeight := self.Height;

	deltaLogWidth := self.Width - Log.Width;
	deltaLogHeight := self.Height - Log.Height;
end;

destructor TKinFertForm.Destroy;
begin
	end_runs;
	if Assigned(myBufferStr) then FreeAndNil(myBufferStr);
	inherited;
end;

procedure TKinFertForm.ReadStdPath (fileName: string; var path: string);
var
	f: TFileType; // used in the main thread only
	res: longint;
begin
	f := TFileType.Create (ExtractFilePath (Application.ExeName) + fileName, res, 'READSTDPATH', f_reset);
	if res = 0 then begin
		readLn (f.fileHandle, path);
	end;
	f.Destroy;
end;

procedure TKinFertForm.saveLog (fileNameWithPath: string);
begin
    if (fileNameWithPath = '') then begin
    	if not checkDir (gPathToResult) then begin
    		memoWriteLn(['ERROR ==> Bad directory: ', gPathToResult]);
    		exit;
    	end;
        fileNameWithPath := gPathToResult + g_FileName.value + '_LOG.TXT';
    end;
	Log.Lines.SaveToFile(fileNameWithPath);
end;

procedure TKinFertForm.SaveOutputClick(Sender: TObject);
begin
	SaveOutputDialog.Title := 'Write log output to a data file';
	SaveOutputDialog.Filter := 'Data file|*.txt';
	SaveOutputDialog.DefaultExt := 'txt';
	if checkDirResult () then
		SaveOutputDialog.InitialDir:= gPathToResult;
	SaveOutputDialog.FileName := g_FileName.value + '_LOG.TXT';
	SaveOutputDialog.Options := SaveOutputDialog.Options + [ofOverwritePrompt];
	if SaveOutputDialog.Execute then
	begin
		Log.Lines.SaveToFile(SaveOutputDialog.Filename);
	end;
end;

procedure TKinFertForm.FormCreate(Sender: TObject);
var
	inIDE: string;
begin
	setLength (gConfigFileCollection, 0);
	simulationRan := False;
	memoWriting := false;
	self.ReadStdPath ('KinFert ConfigDir.cfg', gPathToConfig);
	self.ReadStdPath ('KinFert OutputDir.cfg', gMainPathToResult);
	g_GENPARAM.OUTPUT_DIRECTORY.value := gMainPathToResult;
	OutputDirName.Caption := gMainPathToResult;
	gPathToResult := gMainPathToResult;
	ConfigFileName.caption := gCfgFilename;
	ActiveControl := runSimul;
	self.ClearLog();
	with CED do begin
		Parent := self;
		Picture.LoadFromLazarusResource('CED');
		Stretch := true;
		Left := 584;
		Top := 52;
		Width := trunc (485 / 1.5);
		Height := trunc (187 / 1.5);
	end;
	inIDE := '';
	if gRunFromIDE then inIDE := ' IDE';
	VersionString.caption := 'Version: on ' + {$I %DATE%} + ' at ' + {$I %TIME%} + inIDE;
	errorShape.brush.color := clWhite;
	errorShape.Hint := 'No error';
	errorShape.ShowHint := true;
{	with RedFlag do begin
		Parent := self;
		//Picture.LoadFromLazarusResource('green');
		Stretch := true;
		Left := 472;
		Top := 96;
		Width := 34;
		Height := 34;
		hint := 'No error';
	end;
}
	gDebugError := false;

	ProgressBar.Position := 0;
end;

procedure TKinFertForm.FormResize(Sender: TObject);
begin
	// code to handle the resize event
	Log.Width := self.Width - deltaLogWidth;
	Log.Height := self.Height - deltaLogHeight;
end;

procedure TKinFertForm.UtilesBtnClick(Sender: TObject);
begin
	if gSimulationRunning then begin
		exit;
	end;
	UtilesForm.ShowModal;
end;

procedure TKinFertForm.ChooseConfigButtonClick(Sender: TObject);
// read config file
var
	s: ansistring;
	filename: string;
	numSimul: longint = 0;
begin
	if gSimulationRunning then begin
		exit;
	end;
	self.ClearLog();
	s := 'KinFert config file|*.txt';
	OpenConfigDialog.Filter := s;
	OpenConfigDialog.Options := OpenConfigDialog.Options+[ofFileMustExist];
	if gPathToConfig <> '' then
		OpenConfigDialog.InitialDir := gPathToConfig;
	if not OpenConfigDialog.Execute then exit;
	try
    	setLength (gConfigFileCollection, 0);
    	defaultConfigFile;
    	defaultConfig ();
		initCmd ();
		gCfgFilename := OpenConfigDialog.filename;
		gPathToConfig := ExtractFilePath(gCfgFilename);
		self.setOutputPath(gPathToConfig);
		filename := ExtractFileName(gCfgFilename);
		ConfigFileName.caption := gCfgFilename;
		if readCmdFile (filename, numSimul, true) then begin
			if length (gConfigFileCollection) > 0 then
				self.statusCaption ('Config file collection read...')
			else
				self.statusCaption ('Config file read...');
			if (g_GENPARAM.OUTPUT_DIRECTORY.value <> '') and (gMainPathToResult = '') then begin
				if DirectoryExists(g_GENPARAM.OUTPUT_DIRECTORY.value) then
					gMainPathToResult := g_GENPARAM.OUTPUT_DIRECTORY.value;
				OutputDirName.Caption := gMainPathToResult;
			end;
			WriteStdPath ('KinFert ConfigDir.cfg', gPathToConfig);
		end else
			self.statusCaption ('Error while reading config file');
		self.FlushString({%H-}PtrInt(nil));
	except
		on E: Exception do begin
			MessageDlg('Error','Error: ' + E.Message,mtError,[mbOk],0);
		end;
	end
end;

procedure TKinFertForm.createConfigFileClick(Sender: TObject);
// edit config
var
	oldCaptionStatus: string;
begin
	if gSimulationRunning then begin
		exit;
	end;
	if length (gConfigFileCollection) > 0 then begin
		if not MessageBoxTwoChoices ('Continue and forget multiple file selection?', 'Config a new simulation?') then
			exit;
		setLength (gConfigFileCollection, 0);
		self.ClearLog();
	end;
	oldCaptionStatus := ConfigFileName.caption;
	ConfigForm.ShowModal;
	if (gLazDumpFileName <> '') then begin
		self.statusCaption (gLazDumpFileName + ' written!');
		gCfgFilename := gLazDumpFileName;
	end else if ConfigForm.ChangesMadeToDefaultValues then begin
		gCfgFilename := 'Edited values';
	end else begin
		gCfgFilename := 'Default values';
		self.statusCaption ('No config file written');
	end;

	if (not gConfigValuesEdited) and (ConfigForm.ChangesMadeToDefaultValues) then
		ConfigFileName.caption := oldCaptionStatus
	else
		ConfigFileName.caption := gCfgFilename;
end;

procedure TKinFertForm.FileQuitMenuClick(Sender: TObject);
begin
	if gSimulationRunning then begin
		exit;
	end;
	Self.Show;
	Close;
	Application.Terminate;
	Halt;
end;

procedure TKinFertForm.GraphsBtnClick(Sender: TObject);
begin
	if gSimulationRunning then begin
		exit;
	end;
	GraphsForm.ShowModal;
end;

procedure TKinFertForm.FileOpenMenuClick(Sender: TObject);
begin
	if gSimulationRunning then begin
		exit;
	end;
	ChooseConfigButtonClick(Sender);
end;

procedure TKinFertForm.QuitBtnClick(Sender: TObject);
begin
	if gSimulationRunning then begin
		exit;
	end;
	Self.Show;
	Close;
	Application.Terminate;
	//Halt;
end;

procedure TKinFertForm.Reset_nRunsClick(Sender: TObject);
begin
	if gSimulationRunning then begin
		exit;
	end;
	simulationRan := false;
	clearResults (g_nRuns);
	GraphsForm.ClearAll;
	{defaultConfigFile;
	defaultConfig;}
end;

procedure TKinFertForm.runSimulClick(Sender: TObject);
begin
	if gSimulationRunning then begin
		exit;
	end;
	ProgressBar.Position := 0;
	if (gMainPathToResult = '') then begin
		ShowMessage('Output directory should have been selected first!');
		exit;
	end;
	gSimulationRunning := true;
	
	mainThread := TKinFertMainThread.Create(True); // This way it doesn't start automatically

	gPathToResult := gMainPathToResult;

	LookMemory;
	errorShape.brush.color := clGreen;
	errorShape.Hint := 'No error';
	errorShape.ShowHint := true;
	gDebugError := false;

	gPathToConfig := ExtractFilePath(gCfgFilename);
	
	self.statusCaption ('started');
	self.ClearLog();

{$IFDEF VerboseProfiler}
timeProfile_initProc();
timeProfile_init(2000);
timeProfile_silent();
timeProfile_start();
{$ENDIF}

	mainThread.Start;

end;

procedure TKinFertForm.endSimulation(Sender: TObject);
begin
	self.FlushString({%H-}PtrInt(nil));
	self.statusCaption ('finished, simulation: ' + IntToStr (g_nRuns));
	simulationRan := True;
	if gDebugError then begin
		errorShape.brush.color := clRed;
		errorShape.Hint := 'Error in the code. Look at the debug file...';
		errorShape.ShowHint := true;
		self.statusCaption ('Error in the code. Look at the debug file...');
	end;

	gSimulationRunning := false;
end;

procedure TKinFertForm.AsyncProgressBar(Data: PtrInt);
var
	myData: AsyncData;
begin
	try
		if (not Application.Terminated) then
		begin
			myData := {%H-}pAsyncData(Data)^;
			ProgressBar.Position := round(myData.perCent);
			//ProgressEdit.text := inttostr (round(percent));
			//ProgressEdit.Update;
			Application.ProcessMessages
		end;
	finally
		Dispose({%H-}PAsyncData(Data));
	end;
end;

procedure TKinFertForm.ZipProgressHandler(Sender: TObject; const percent: Double);
var
	pData: pAsyncData;
begin
	new (pData);
	pData^.perCent := percent;
	Application.QueueAsyncCall(@AsyncProgressBar, {%H-}PtrInt(pData));
end;

procedure TKinFertForm.setOutputPath(path:string);
begin
	gMainPathToResult := path;
	g_GENPARAM.OUTPUT_DIRECTORY.value := gMainPathToResult;
	OutputDirName.Caption := gMainPathToResult;
	self.WriteStdPath ('KinFert OutputDir.cfg', gMainPathToResult);
end;

procedure TKinFertForm.OutputDirButtonClick(Sender: TObject);
var
	path: string;
begin
	if gSimulationRunning then begin
		exit;
	end;
	if OutputDirectoryDialog.Execute then
	begin
		path := OutputDirectoryDialog.FileName + PathDelim;
		self.setOutputPath(path);
		self.statusCaption ('Output directory selected..');
	end;
end;

procedure TkinFertForm.WriteStdPath (fileName, path: string);
var
	f: TFileType; // used in the main thread only
	aDir: string;
	res: longint;
begin
	aDir := ExtractFilePath (Application.ExeName);
	f := TFileType.Create (aDir + fileName, res, 'WRITESTDPATH');
	if res = 0 then begin
		cWriteLn (f, path);
	end;
	f.Destroy;
end;

procedure TKinFertForm.AsyncFlushString;
begin
	Application.QueueAsyncCall(@FlushString, {%H-}PtrInt(nil));
end;

procedure TKinFertForm.FlushString(Data: PtrInt);
var
	ind: longint;
begin
	if (not Application.Terminated) then begin
		myUpdateCount := 0;
		if myBufferStr.Count = Log.Lines.Count then exit;
		Log.lines.beginUpdate;
		Log.WordWrap := False;
		for ind := Log.Lines.Count + 1 to myBufferStr.Count do
			Log.Lines.Add (myBufferStr.Strings[ind-1]);
		Log.sellength := 0;
		{$IFDEF WINDOWS}
		SendMessage(Log.Handle, EM_SCROLLCARET, 0, 0);
		{$ENDIF}
		Log.SetFocus;
		//Log.WordWrap := True;
		Log.SelStart := Length(Log.Text);
		Log.CaretPos := Point(0, Log.Lines.Count-1);
		Log.lines.endUpdate;
		Log.SelStart := Length(Log.Text);
		Log.CaretPos := Point(0, Log.Lines.Count-1);
	end;
end;

procedure TKinFertForm.ClearLog;
begin
	//Log.text := '';
	Log.Clear;
	myBufferStr.Clear;
	myLine := '';
	myUpdateCount := 0;
end;

procedure TKinFertForm.writeExec(pData: pAsyncData);
begin
	IOResult;
	assignFile (pData^.outFile.fileHandle, pData^.outFile.filenameWithPath);
	if pData^.outFile.writtenTo then
		append(pData^.outFile.fileHandle)
	else
		rewrite(pData^.outFile.fileHandle);
	if pData^.text = pData^.outFile.messageEnd then
		pData^.outFile.FAFinished := true
	else begin
		write (pData^.outFile.fileHandle, pData^.text);
		pData^.outFile.writtenTo := true;
	end;
	closeFile (pData^.outFile.fileHandle);
end;

procedure TKinFertForm.AsyncWrite(Data: PtrInt);
var
	pData: pAsyncData;
begin
	try
		if (not Application.Terminated) then
		begin
			pData := {%H-}pAsyncData(Data);
			self.writeExec (pData);
		end;
	finally
		Dispose({%H-}PAsyncData(Data));
	end;
end;

procedure TKinFertForm.myWrite(outFile: TFileType; s: string);
var
	pData: pAsyncData;
begin
	new (pData);
	pData^.text := s;
	pData^.outFile := outFile;
	Application.QueueAsyncCall(@AsyncWrite, {%H-}PtrInt(pData));
end;

procedure TKinFertForm.writeLnExec(pData: pAsyncData);
begin
	IOResult;
	assignFile (pData^.outFile.fileHandle, pData^.outFile.filenameWithPath);
	if pData^.outFile.writtenTo then
		append(pData^.outFile.fileHandle)
	else
		rewrite(pData^.outFile.fileHandle);
	writeLn (pData^.outFile.fileHandle, pData^.text);
	pData^.outFile.writtenTo := true;
	closeFile (pData^.outFile.fileHandle);
end;

procedure TKinFertForm.AsyncWriteLn(Data: PtrInt);
var
	pData: pAsyncData;
begin
	try
		if (not Application.Terminated) then
		begin
			pData := {%H-}pAsyncData(Data);
			self.writeLnExec (pData);
		end;
	finally
		Dispose({%H-}PAsyncData(Data));
	end;
end;

procedure TKinFertForm.myCloseFiles(Data: PtrInt);
begin
	closeAllFiles();
end;

procedure TKinFertForm.myWriteLn(outFile: TFileType; s: string);
var
	pData: pAsyncData;
begin
	new (pData);
	pData^.text := s;
	pData^.outFile := outFile;
	Application.QueueAsyncCall(@AsyncWriteLn, {%H-}PtrInt(pData));
end;

procedure TKinFertForm.doMemoWrite(s: string);
var
	pData: pAsyncData;
begin
	new (pData);
	pData^.text := s;
	Application.QueueAsyncCall(@AsyncMemoWrite, {%H-}PtrInt(pData));
end;

procedure TKinFertForm.MemoWriteExec(s: string);
begin
	myLine := myLine + s;
	myUpdateCount := myUpdateCount + length(s);

	self.statusCaptionExec ( gWorkingMessage + '... ' );
end;

procedure TKinFertForm.AsyncMemoWrite(Data: PtrInt);
var
	myData: AsyncData;
begin
	try
		if (not Application.Terminated) then
		begin
			myData := {%H-}pAsyncData(Data)^;
			self.MemoWriteExec (myData.text);
		end;
	finally
		Dispose({%H-}PAsyncData(Data));
	end;
end;

procedure TKinFertForm.MemoWriteLnExec(s: string);
var
	strDots: string = '......';
    countDots: longint = 1;
begin
	s := myLine + s;
	myBufferStr.Add (s);
	myUpdateCount := myUpdateCount + length(s);
	if (s = kEndThreadMessage) then begin
		self.FlushString({%H-}PtrInt(nil));
        memoWriting := false;
	end;

	if (myUpdateCount > 0) or simulationRan then begin
        countDots := max(1, trunc(myUpdateCount / 10));
        countDots := min(6, countDots);
		self.FlushString({%H-}PtrInt(nil));
		self.statusCaptionExec ( gWorkingMessage + ' ' + copy (strDots, 1, countDots) );
	end else begin
        if myUpdateCount < 50 then
        	self.statusCaptionExec ( gWorkingMessage + ' ...' )
		else
			self.statusCaptionExec ( gWorkingMessage + ' ......' );
	end;
end;

procedure TKinFertForm.AsyncMemoWriteLn(Data: PtrInt);
var
	myData: AsyncData;
begin
	try
		if (not Application.Terminated) then
		begin
			myData := {%H-}pAsyncData(Data)^;
			self.MemoWriteLnExec (myData.text);
		end;
	finally
		Dispose({%H-}PAsyncData(Data));
	end;
end;

procedure TKinFertForm.doMemoWriteLn(s: string);
var
	pData: pAsyncData;
begin
	new (pData);
	pData^.text := s;
	Application.QueueAsyncCall(@AsyncMemoWriteLn, {%H-}PtrInt(pData));
end;

procedure TKinFertForm.statusCaptionExec(s: string);
begin
	status.caption := s;
end;

procedure TKinFertForm.statusCaption(s: string);
	var
	pData: pAsyncData;
begin
	new (pData);
	pData^.text := s;
	Application.QueueAsyncCall(@AsyncStatusCaption, {%H-}PtrInt(pData));
end;

procedure TKinFertForm.AsyncStatusCaption(Data: PtrInt);
var
	myData: AsyncData;
begin
	try
		if (not Application.Terminated) then
		begin
			myData := {%H-}pAsyncData(Data)^;
			self.statusCaptionExec (myData.text);
		end;
	finally
		Dispose({%H-}PAsyncData(Data));
	end;
end;

procedure TKinFertForm.MainThreadMessage(sender: TObject; s: string);
begin
	memoWriteLn ([s]);
	if s = kEndThreadMessage then
		self.endSimulation(sender)
end;

{=============== KinFertMainThread class ================}
Constructor TKinFertMainThread.Create(CreateSuspended : boolean);
begin
	inherited Create(CreateSuspended);
	FreeOnTerminate := True;
	OnTerminate := @KinFertForm.endSimulation;
end;

procedure TKinFertMainThread.ShowStatus;
// this method is executed by the mainthread and can therefore access all GUI elements.
begin
	KinFertForm.MainThreadMessage(self, fStatusText);
end;

procedure TKinFertMainThread.Execute;
var
	filename: string;
	indFile: longint;
	nFiles: longint = 1;
	label error;
begin
	FAFinished:=false;
	KinFertForm.memoWriting := true;
	fStatusText := 'KinFert main thread starting...';
	//Synchronize(@Showstatus);
	memoWriteLn ([fStatusText]);

	if length (gConfigFileCollection) > 0 then begin
		nFiles := length (gConfigFileCollection);
	end;
	for indFile := 1 to nFiles do begin
		Inc (g_nRuns);
		if length (gConfigFileCollection) > 0 then begin
			filename := gConfigFileCollection [indFile-1];
			KinFertForm.ZipProgressHandler(KinFertForm, 0);
			if not doIt ( filename, initAndReadFile ) then goto error;
			if (g_GENPARAM.SAVE_LOG.value) then
				KinFertForm.SaveLog('');
		end else begin
			filename := ExtractFileName(gCfgFilename);
			if (g_nRuns > 1) then begin
				//if adjustedValuesSaved() and MessageBoxTwoChoices ('Run new simulation and forget adjusted values?', 'Reset environment') then begin
					initAdjustedValues();
					if not doIt ( filename, noInitAndNoReadFile ) then goto error;
					if (g_GENPARAM.SAVE_LOG.value) then
						KinFertForm.SaveLog('');
				//end else
				//	doIt ( filename, noInitAndNoReadFile );
			end else
				if not doIt ( filename, noInitAndNoReadFile ) then goto error;
				if (g_GENPARAM.SAVE_LOG.value) then
					KinFertForm.SaveLog('');
		end;
	end;

	if length (gConfigFileCollection) > 0 then begin
		SetLength (gConfigFileCollection, 0);
		Init_runs;
	end;

	error:
	
{$IFDEF VerboseProfiler}
	timeProfile_talkative(); timeProfile_end();
	timeProfile_print_proc ();
{$ENDIF}
	fStatusText := kEndThreadMessage;
	//Synchronize(@Showstatus);
	memoWriteLn ([fStatusText]);
	while (KinFertForm.memoWriting) do
	// wait for memo log update to complete
		;
	if (g_GENPARAM.SAVE_LOG.value) then
		KinFertForm.SaveLog('');
	FAFinished:= true;
end;
initialization
{$I kinfertres.lrs}

end.


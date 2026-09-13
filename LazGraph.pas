unit LazGraph;

{$mode objfpc}{$H+}

interface

uses
	{$IFDEF UNIX}
	cthreads,
	{$ENDIF}
	Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, ComCtrls, ExtCtrls, StdCtrls,
	Declarations, DemographicRegime, Kinship, Fertility, Utilities, StringOfLib, Math,
	FPCanvas,
	TACustomSeries,
	TAGraph, TASeries, TAChartAxis, TASources, TALegend,
	TAChartAxisUtils, TAChartUtils, TACustomSource, TATransformations, TATypes;

type
	arrayOfTFPPenStyle = array of TFPPenStyle;
	
TDrawParameters = class
	public
	legendX: string;
	legendY: string;
	seriesTitle: string;
	chartTitle: string;
	legendTitle: string;
	lastValueIsTotal: boolean;
	labelsX: array of double;
	labelsY: array of double;
	scaleFactorX, scaleFactorY: double;
	offsetLabelX: longint;
	rangeValuesX: array of longint;
	{A marker at each point of the curve, psNone for a plain line. Set it on a curve that has to
	 be told apart from another one it nearly coincides with, which is the case of every observed
	 curve drawn beside the input it is read against.}
	markerStyle: TSeriesPointerStyle;
	Constructor Create(lx: string; ly: string); overload;
	Constructor Create(lx: string; ly: string; st: string; ct: string = ''; lt: string = ''; lvt: boolean = false; sF: double = 1.0); overload;
	Constructor Create(lx: string; ly: string; st: string; ct: string; lt: string; lvt: boolean; sF: double; olx: longint;
				const lbx: array of const; const lby: array of const); overload;
	Destructor Destroy; override;
	procedure Init(lx: string = ''; ly: string = ''; st: string = ''; ct: string = ''; lt: string = ''; lvt: boolean = false; sF: double = 1.0; olx: longint = 0); overload;
	procedure Init(lx: string = ''; ly: string = ''; st: string = ''; ct: string = ''; lt: string = ''; lvt: boolean = false; sF: double = 1.0; olx: longint = 0;
				const lbx: array of const; const lby: array of const); overload;
	procedure Init(const lbx: array of const; const lby: array of const); overload;
end;

	{ TGraphsForm }

TGraphsForm = class(TForm)
	ageEgoLab: TLabel;
	InputsVarCohorts: TComboBox;
	kinEgoLab: TLabel;
	OKOutputKinship: TButton;
	OKOutputFertility: TButton;
	OKVariableInputs: TButton;
	OKChildGroom: TButton;
	OKFixedInputs: TButton;
	sexEgoLab: TLabel;
	Chart1: TChart;
	Chart2: TChart;
	Chart3: TChart;
	Chart4: TChart;
	Chart5: TChart;
	ChildGroomList: TComboBox;
	InputsList: TComboBox;
	InputsVarList: TComboBox;
	OutputsList: TComboBox;
	OutputsKinshipList: TComboBox;
	AgeKinshipList: TComboBox;
	sexList: TComboBox;
	KinTypesList: TComboBox;
	SaveDialog: TSaveDialog;
	SaveToFileOutputsFertility: TButton;
	SaveToFileChildGroomInfo: TButton;
	SaveToFileFixedOutputs: TButton;
	SaveToFileVariableOutputs: TButton;
	SaveToFileOutputsKinship: TButton;
	SimulationStatus: TLabel;
	SimulationStatusOutputs: TLabel;

	PageControl1: TPageControl;
	InputsSheet: TTabSheet;
	InputsVarSheet: TTabSheet;
	OutputsFertilitySheet: TTabSheet;
	OutputsKinshipSheet: TTabSheet;
	SimulationStatusOutputsKinship: TLabel;
	ChildGroomSheet: TTabSheet;
	procedure OKOutputKinshipClick(Sender: TObject);
	procedure FormCreate(Sender: TObject);
	procedure FormResize(Sender: TObject);
	procedure FormActivate(Sender: TObject);
	procedure ClearAll();
	procedure CreateManualAxis(aChart: TChart; alignment: TChartAxisAlignment);
	procedure DrawIntegers(aChart: TChart; n: Integer; const a: array of longint; par: TDrawParameters);
	procedure Draw(aChart: TChart; n: Integer; const a: array of double; par: TDrawParameters); overload;
	procedure setSeriesColor(aChart: TChart; n: Integer; aColor: TColor);
	function simulatedTitle(lastSettingOnly: boolean): string;
	function chartTitleFor(base: string; hasObserved: boolean): string;
	procedure Draw(aChart: TChart; n: Integer; const a: array of double;
								legendX: string = ''; legendY: string = ''; seriesTitle: string = ''; chartTitle: string = '';
								lastValueIsTotal: boolean = false); overload;
	procedure Draw(aChart: TChart; n: Integer; const a: array of double;
								legendX: string = ''; legendY: string = ''; seriesTitle: string = ''; chartTitle: string = ''; lastValueIsTotal: boolean = false;
								const labelsX: array of const; const labelsY: array of const); overload;
	procedure InputsCreate;
	procedure InputsChange(Sender: TObject);
	procedure InputsEnter(Sender: TObject);
	procedure InputsClose(Sender: TObject);
	procedure InputsVarCreate;
	procedure InputsVarChange(Sender: TObject);
	procedure InputsVarEnter(Sender: TObject);
	procedure InputsVarClose(Sender: TObject);
	procedure InputsVarCohortsCreate;
	procedure InputsVarCohortsChange(Sender: TObject);
	procedure OutputsCreate;
	procedure OutputsChange(Sender: TObject);
	procedure OutputsEnter(Sender: TObject);
	procedure OutputsClose(Sender: TObject);
	procedure OutputsKinshipCreate;
	procedure OutputsKinshipChange(Sender: TObject);
	procedure OutputsKinshipEnter(Sender: TObject);
	procedure OutputsKinshipClose(Sender: TObject);
	procedure AgeKinshipCreate;
	procedure AgeKinshipChange(Sender: TObject);
	procedure KinTypesCreate;
	procedure SexCreate;
	procedure ChildGroomCreate;
	procedure ChildGroomChange(Sender: TObject);
// >>> Claude 2026-09-12 start
	procedure drawUnionsByGroomCohort;
	procedure drawSearchBoth;
	procedure drawSearchByGeneration (const total, miss: array of arrayOfLongint; what: string;
								firstCohort, lastCohort, marginBelow, marginAbove: longint);
	function addSearchCurve (const total, miss: array of arrayOfLongint; seriesTitle: string;
								firstCohort, marginBelow, generation, n: longint;
								out firstDrawn, lastDrawn, nSearches, nMissed: longint;
								out worstPct: double): boolean;
	procedure setSeriesXY (aChart: TChart; n: longint; const xs, ys: array of double);
	procedure setChart5Axis (title, labelX, labelY: string; first, last: longint; yMax: double);
	procedure noSearchRecorded (what: string);
	function searchSummary (nSearches, nMissed: longint): string;
// <<< Claude 2026-09-12 end
	procedure ChildGroomEnter(Sender: TObject);
	procedure ChildGroomClose(Sender: TObject);
	procedure KinTypesChange(Sender: TObject);
	procedure SexChange(Sender: TObject);
	procedure SimulationStatusEnter(Sender: TObject);
	procedure SaveChartSeriesToFile(ASeriesList: TChartSeriesList; aTitle: String = '');
	procedure SaveToFileFixedInputsClick(Sender: TObject);
	procedure SaveToFileVariableInputsClick(Sender: TObject);
	procedure SaveToFileOutputsFertilityClick(Sender: TObject);
	procedure SaveToFileOutputsKinshipClick(Sender: TObject);
	procedure SaveToFileChildGroomInfoClick(Sender: TObject);

	private

	public
	prop_colors: arrayOfLongint;
	prop_linetypes: arrayOfTFPPenStyle;
	prop_currCohort: longint;
	prop_cohorts: arrayOflongint;
	prop_pDemReg: pStructDemographicRegimeSettings;

end;

var
	GraphsForm: TGraphsForm;

implementation
uses
	LazMain;

var
	deltaChart1Width, deltaChart1Height: longint;
	deltaChart2Width, deltaChart2Height: longint;
	deltaChart3Width, deltaChart3Height: longint;
	deltaChart4Width, deltaChart4Height: longint;
	deltaChart5Width, deltaChart5Height: longint;
	deltaPageControl1Width, deltaPageControl1Height: longint;
	
	delta_fr_Save_OutputKinship, delta_fr_OK_OutputKinship: longint;
	delta_fr_Save_OutputFertility, delta_fr_OK_OutputFertility: longint;
	delta_fr_Save_VariableInputs, delta_fr_OK_VariableInputs: longint;
	delta_fr_Save_ChildGroom, delta_fr_OK_ChildGroom: longint;
	delta_fr_Save_FixedInputs, delta_fr_OK_FixedInputs: longint;

const
	kMaxSeries = 40;
	kNoSeriesTitle = '';
	kNoChartTitle = '';
	kNoLegendTitle = '';
	kLastValueIsNotTotal = false;
	kLastValueIsTotal = true;
	kNoScaleFactor = 1.0;
	kNoOffsetX = 0;

	procedure SaveToFile(ASeriesList: TChartSeriesList; AFileName: String);
	const
		off = 1;
	var
		f: TextFile; // Used only by the main thread
		i, n, nData, nSeries: Integer;
		data: array of string;
		aSerie: TChartSeries;
	begin
		try
			AssignFile (f, AFileName);
			Rewrite (f);
			nSeries := ASeriesList.Count;
			// we suppose for the moment that all the series have the same X
			aSerie := TChartSeries (ASeriesList.Items[0]);
			nData := aSerie.ListSource.Count;
			SetLength (data{%H-}, nData + off);

			data[0] := 'X';
			for i := 0 to nData-1 do begin
				data[i+off] := data[i+off] + FloatToStr (aSerie.ListSource.Item[i]^.X);
			end;
			for n := 0 to nSeries-1 do begin
				aSerie := TChartSeries (ASeriesList.Items[n]);
				if aSerie.Title <> '' then
					data[0] := data[0] + Tab + aSerie.Title
				else
					data[0] := data[0] + Tab + 'Y' + IntToStr(n);
				for i := 0 to nData-1 do begin
					data[i+off] := data[i+off] + Tab + FloatToStr (aSerie.ListSource.Item[i]^.Y);
				end;
			end;
			for i := 0 to nData do
				WriteLn(f, data[i]);
		finally
			CloseFile (f);
			SetLength(data, 0 );
		end;
	end;

	constructor TDrawParameters.Create(lx: string; ly: string);
	begin
		inherited Create();
		Init(lx, ly, '', '', '', false, kNoScaleFactor, kNoOffsetX);
	end;

	Constructor TDrawParameters.Create(lx: string; ly: string; st: string; ct: string = ''; lt: string = ''; lvt: boolean = false; sF: double = kNoScaleFactor); overload;
	begin
		inherited Create();
		Init(lx, ly, st, ct, lt, lvt, sF, kNoOffsetX, [], []);
	end;

	Constructor TDrawParameters.Create(lx: string; ly: string; st: string; ct: string; lt: string; lvt: boolean; sF: double; olx: longint;
			const lbx: array of const; const lby: array of const);
	begin
		inherited Create();
		Init(lx, ly, st, ct, lt, lvt, sF, olx, lbx, lby);
	end;

	Destructor TDrawParameters.Destroy;
	begin
		SetLength(labelsX, 0);
		SetLength(labelsY, 0);
		SetLength(rangeValuesX, 0);
		inherited;
	end;

	procedure TDrawParameters.Init(lx: string = ''; ly: string = ''; st: string = ''; ct: string = ''; lt: string = ''; lvt: boolean = false;
											sF: double = kNoScaleFactor; olx: longint = kNoOffsetX);
	begin
		Init(lx, ly, st, ct, lt, lvt, sF, olx, [], []);
	end;

	procedure TDrawParameters.Init(lx: string = ''; ly: string = ''; st: string = ''; ct: string = ''; lt: string = ''; lvt: boolean = false;
								sF: double = kNoScaleFactor; olx: longint = kNoOffsetX;
							const lbx: array of const; const lby: array of const);
	begin
		legendX := lx;
		legendY := ly;
		seriesTitle := st;
		chartTitle := ct;
		legendTitle := lt;
		lastValueIsTotal := lvt;
		markerStyle := psNone;
		Init (lbx, lby);
		scaleFactorY := sF;
		scaleFactorX := kNoScaleFactor;
		offsetLabelX := olx;
	end;

	function initArray (const a: array of const): ArrayOfDouble;
	var
		i: longint;
		b: array of double;
	begin
		SetLength(b{%H-}, 0);
		if High(a) > 0 then begin
			for i := 0 to High(a) do begin
				SetLength(b, i+1);
				with a[i] do
				case VType of
					vtInteger: b[i] := VInteger;
					vtExtended: b[i] := VExtended^;
				end;
			end;
		end;
		initArray := b;
	end;

	procedure TDrawParameters.Init(const lbx: array of const; const lby: array of const);
	begin
		labelsX := initArray (lbx);
		labelsY := initArray (lby);
	end;

{$R *.lfm}
	procedure TGraphsForm.FormCreate(Sender: TObject);
	begin
		CreateManualAxis (Chart1, calLeft);
		CreateManualAxis (Chart1, calBottom);
		CreateManualAxis (Chart2, calLeft);
		CreateManualAxis (Chart2, calBottom);
		CreateManualAxis (Chart3, calLeft);
		CreateManualAxis (Chart3, calBottom);
		CreateManualAxis (Chart4, calLeft);
		CreateManualAxis (Chart4, calBottom);
		CreateManualAxis (Chart5, calLeft);
		CreateManualAxis (Chart5, calBottom);
		ChildGroomSheet.caption := 'Children-Grooms info';
		InputsSheet.caption := 'Inputs: fixed';
		InputsVarSheet.caption := 'Inputs: variable';
		OutputsFertilitySheet.caption := 'Outputs: Fertility';
		OutputsKinshipSheet.caption := 'Outputs: Kinship';

		prop_colors := arrayOfLongint.Create(
			clRed, clBlue, clLime, clFuchsia, clAqua, clYellow, clMaroon, clGreen, clOlive, clNavy,
			clRed, clBlue, clLime, clFuchsia, clAqua, clYellow, clMaroon, clGreen, clOlive, clNavy,
			clRed, clBlue, clLime, clFuchsia, clAqua, clYellow, clMaroon, clGreen, clOlive, clNavy,
			clRed, clBlue, clLime, clFuchsia, clAqua, clYellow, clMaroon, clGreen, clOlive, clNavy
			);
		prop_linetypes := arrayOfTFPPenStyle.Create(
				psSolid, psSolid, psSolid, psSolid, psSolid, psSolid, psSolid, psSolid, psSolid, psSolid,
				psDash, psDash, psDash, psDash, psDash, psDash, psDash, psDash, psDash, psDash,
				psDot, psDot, psDot, psDot, psDot, psDot, psDot, psDot, psDot, psDot,
				psDashDotDot, psDashDotDot, psDashDotDot, psDashDotDot, psDashDotDot, psDashDotDot, psDashDotDot, psDashDotDot, psDashDotDot, psDashDotDot
			);

		Self.Constraints.MinWidth := self.Width;
		Self.Constraints.MinHeight := self.Height;

		deltaChart1Width := self.Width - Chart1.Width;
		deltaChart1Height := self.Height - Chart1.Height;
		deltaChart2Width := self.Width - Chart2.Width;
		deltaChart2Height := self.Height - Chart2.Height;
		deltaChart3Width := self.Width - Chart3.Width;
		deltaChart3Height := self.Height - Chart3.Height;
		deltaChart4Width := self.Width - Chart4.Width;
		deltaChart4Height := self.Height - Chart4.Height;
		deltaChart5Width := self.Width - Chart5.Width;
		deltaChart5Height := self.Height - Chart5.Height;
		deltaPageControl1Width := self.Width - PageControl1.Width;
		deltaPageControl1Height := self.Height - PageControl1.Height;

		delta_fr_Save_OutputKinship := self.width - SaveToFileOutputsKinship.left;
		delta_fr_OK_OutputKinship := self.width - OKOutputKinship.left;
		delta_fr_Save_OutputFertility := self.width - SaveToFileOutputsFertility.left;
		delta_fr_OK_OutputFertility := self.width - OKOutputFertility.left;
		delta_fr_Save_VariableInputs := self.width - SaveToFileVariableOutputs.left;
		delta_fr_OK_VariableInputs := self.width - OKVariableInputs.left;
		delta_fr_Save_ChildGroom := self.width - SaveToFileChildGroomInfo.left;
		delta_fr_OK_ChildGroom := self.width - OKChildGroom.left;
		delta_fr_Save_FixedInputs := self.width - SaveToFileFixedOutputs.left;
		delta_fr_OK_FixedInputs := self.width - OKFixedInputs.left;
		
	end;

	procedure TGraphsForm.FormResize(Sender: TObject);
	begin
		// code to handle the resize event
		Chart1.Width := self.Width - deltaChart1Width;
		Chart1.Height := self.Height - deltaChart1Height;
		Chart2.Width := self.Width - deltaChart2Width;
		Chart2.Height := self.Height - deltaChart2Height;
		Chart3.Width := self.Width - deltaChart3Width;
		Chart3.Height := self.Height - deltaChart3Height;
		Chart4.Width := self.Width - deltaChart4Width;
		Chart4.Height := self.Height - deltaChart4Height;
		Chart5.Width := self.Width - deltaChart5Width;
		Chart5.Height := self.Height - deltaChart5Height;
		PageControl1.Width := self.Width - deltaPageControl1Width;
		PageControl1.Height := self.Height - deltaPageControl1Height;

		SaveToFileOutputsKinship.left := self.width - delta_fr_Save_OutputKinship;
		OKOutputKinship.left := self.width - delta_fr_OK_OutputKinship;
		SaveToFileOutputsFertility.left := self.width - delta_fr_Save_OutputFertility;
		OKOutputFertility.left := self.width - delta_fr_OK_OutputFertility;
		SaveToFileVariableOutputs.left := self.width - delta_fr_Save_VariableInputs;
		OKVariableInputs.left := self.width - delta_fr_OK_VariableInputs;
		SaveToFileChildGroomInfo.left := self.width - delta_fr_Save_ChildGroom;
		OKChildGroom.left := self.width - delta_fr_OK_ChildGroom;
		SaveToFileFixedOutputs.left := self.width - delta_fr_Save_FixedInputs;
		OKFixedInputs.left := self.width - delta_fr_OK_FixedInputs;
	end;

	procedure TGraphsForm.OKOutputKinshipClick(Sender: TObject);
	begin
		ModalResult := mrClose;
	end;

	procedure TGraphsForm.FormActivate(Sender: TObject);
	begin
		PageControl1.ActivePage := InputsSheet;
		InputsCreate;
		InputsVarCohortsCreate;
		InputsVarCreate;
		OutputsCreate;
		AgeKinshipCreate;
		KinTypesCreate;
		SexCreate;
		OutputsKinshipCreate;
		ChildGroomCreate;
	end;

	procedure TGraphsForm.ClearAll();
	begin
		Chart1.ClearSeries;
		Chart2.ClearSeries;
		Chart3.ClearSeries;
		Chart4.ClearSeries;
		Chart5.ClearSeries;
	end;

	procedure TGraphsForm.CreateManualAxis(aChart: TChart; alignment: TChartAxisAlignment);
	var
		chartAxis: TChartAxis;
	begin
		chartAxis := aChart.AxisList.Add;
		chartAxis.Alignment := alignment;
		chartAxis.Intervals.Options := [];
		case alignment of
			calLeft	: chartAxis.Title.LabelFont.Orientation := +900;
			calRight : chartAxis.Title.LabelFont.Orientation := -900;
		end;
	end;

	procedure TGraphsForm.Draw(aChart: TChart; n: Integer; const a: array of double;
									legendX: string = ''; legendY: string = ''; seriesTitle: string = ''; chartTitle: string = ''; lastValueIsTotal: boolean = false);
	begin
		Draw(aChart, n, a, TDrawParameters.Create(legendX, legendY, seriesTitle, chartTitle, kNoLegendTitle, lastValueIsTotal));
	end;

	type
		minMax = (minVal, maxVal);

	procedure TGraphsForm.DrawIntegers(aChart: TChart; n: Integer; const a: array of longint; par: TDrawParameters);
	var
		b: array of double;
		ind, len: longint;
	begin
		len := length(a);
		setLength (b{%H-}, len);
		for ind := 0 to len-1 do
			b[ind] := a[ind];
		self.Draw(aChart, n, b, par);
		setLength (b, 0);
	end;

	function TGraphsForm.chartTitleFor(base: string; hasObserved: boolean): string;
	{The title of a chart that draws an input and, once a simulation has run, what the run drew
	 beside it. Before the first run there is one curve and the title names it alone.}
	begin
		if hasObserved then
			result := base + ' (theoretical and simulated)'
		else
			result := base;
	end;

	function TGraphsForm.simulatedTitle(lastSettingOnly: boolean): string;
	{The legend entry of an observed curve. A sweep, or a run of several cohorts, simulates more
	 than one setting. The quantities the demographic regime defines are counted for the last
	 setting alone, since their input differs between settings; the others are counted over the
	 whole run, their input being the same in every one. The legend says which of the two the
	 curve is, and does not say it at all when only one setting ran.}
	begin
		if (gCountSimulationSettings <= 1) then
			result := 'Simulated'
		else if lastSettingOnly then
			result := 'Simulated, last of ' + IntToStr (gCountSimulationSettings) + ' settings'
		else
			result := 'Simulated, all ' + IntToStr (gCountSimulationSettings) + ' settings';
	end;

	procedure TGraphsForm.setSeriesColor(aChart: TChart; n: Integer; aColor: TColor);
	{Overrides the colour prop_colors gives by position. For a curve whose meaning is fixed
	 rather than positional, the standard of a relational model for instance, the colour should
	 not change with the number of curves drawn beside it.}
	begin
		if (n >= 1) and (n <= aChart.SeriesCount) then
			TLineSeries (aChart.Series [n-1]).SeriesColor := aColor;
	end;

	procedure TGraphsForm.Draw(aChart: TChart; n: Integer; const a: array of double; par: TDrawParameters);
	var
		i, nData, nSeries: Integer;
		x, max, min: Double;
		chartSeries: TLineSeries;
		ListChartSourceX, ListChartSourceY: TListChartSource;
		manualLeftChartAxis, manualBottomCharAxis: TChartAxis;
		addLegend: boolean = false;
		addTitle: boolean = false;
		rangeValuesX: array [minMax] of longint;
	begin
		if (n < 1) or (n > kMaxSeries) then exit;
		addLegend := (n > 1);
		addTitle := (par.chartTitle <> '');
		nSeries := aChart.SeriesCount;
		if n = 20 then
			n := n;
		if n = nSeries + 1 then begin
			chartSeries := TLineSeries.Create(aChart);
			aChart.AddSeries(chartSeries);
		end else begin
			chartSeries := TLineSeries(aChart.Series[n-1]);
		end;
		chartSeries.Clear;
		nData := length (a);
		rangeValuesX[minVal] := 0;
		rangeValuesX[maxVal] := nData - 1;
		if (length (par.rangeValuesX) > 0) then
			rangeValuesX[minVal] := par.rangeValuesX[0] - 1;
		if (length (par.rangeValuesX) > 1) then
			if (par.rangeValuesX[1] < rangeValuesX[maxVal] + 1) then
				rangeValuesX[maxVal] := par.rangeValuesX[1] - 1;
		if par.lastValueIsTotal then Dec (rangeValuesX[maxVal]);
		for i := rangeValuesX[minVal] to rangeValuesX[maxVal] do begin
			x := i;
			chartSeries.AddXY(
								(x + par.offsetLabelX) * par.scaleFactorX,
								a[i] * par.scaleFactorY
								);
		end;
		chartSeries.SeriesColor := prop_colors[n-1];
		chartSeries.LinePen.Style := prop_linetypes[n-1];
		{a hollow marker, so that the line under it stays visible and two curves that nearly
		 coincide can still be told apart}
		chartSeries.ShowPoints := (par.markerStyle <> psNone);
		if chartSeries.ShowPoints then begin
			chartSeries.Pointer.Style := par.markerStyle;
			chartSeries.Pointer.HorizSize := 3;
			chartSeries.Pointer.VertSize := 3;
			chartSeries.Pointer.Brush.Color := clWhite;
			chartSeries.Pointer.Pen.Color := prop_colors[n-1];
			chartSeries.Pointer.Visible := true;
		end;
		if par.seriesTitle <> '' then
			chartSeries.Title := par.seriesTitle
		else
			chartSeries.Title := IntToStr(n);

		manualLeftChartAxis := aChart.AxisList[2];
		if High(par.labelsY) > 0 then begin
			ListChartSourceY := TListChartSource.Create(aChart);
			for i := 0 to High(par.labelsY) do begin
				ListChartSourceY.add(par.labelsY[i], par.labelsY[i]);
			end;
			manualLeftChartAxis.Marks.Source := ListChartSourceY;
			manualLeftChartAxis.Title.caption := par.legendY;
			manualLeftChartAxis.Title.visible := true;
			manualLeftChartAxis.visible := true;
			max := par.labelsY[High(par.labelsY)];
			min := par.labelsY[Low(par.labelsY)];
			manualLeftChartAxis.range.max := max;
			manualLeftChartAxis.range.min := min;
			manualLeftChartAxis.range.usemax := true;
			manualLeftChartAxis.range.usemin := true;
			aChart.LeftAxis.visible := false;
		end else begin
			aChart.LeftAxis.Title.caption := par.legendY;
			aChart.LeftAxis.Title.visible := true;
			aChart.LeftAxis.visible := true;
			manualLeftChartAxis.visible := false;
		end;

		manualBottomCharAxis := aChart.AxisList[3];
		if High(par.labelsX) > 0 then begin
			ListChartSourceX := TListChartSource.Create(aChart);
			for i := 0 to High(par.labelsX) do begin
				ListChartSourceX.add(par.labelsX[i], par.labelsX[i]);
			end;
			manualBottomCharAxis.Marks.Source := ListChartSourceX;
			manualBottomCharAxis.Title.caption := par.legendX;
			manualBottomCharAxis.Title.visible := true;
			manualBottomCharAxis.visible := true;
			aChart.BottomAxis.visible := false;
		end else begin
			aChart.BottomAxis.Title.caption := par.legendX;
			aChart.BottomAxis.Title.visible := true;
			aChart.BottomAxis.visible := true;
			manualBottomCharAxis.visible := false;
		end;

		if addLegend then begin
			aChart.Legend.Visible := true;
			aChart.Legend.Alignment := laBottomCenter;
			aChart.Legend.ColumnCount := 10;
		end else begin
			aChart.Legend.Visible := false;
		end;

		if addTitle then begin
			aChart.Title.Text.Strings[0] := par.chartTitle;
			aChart.Title.Font.Size := 16;
			aChart.Title.Visible := true;
		end else begin
			aChart.Title.Visible := false;
		end;
	end;

	procedure TGraphsForm.Draw(aChart: TChart; n: Integer; const a: array of double;
									legendX: string = ''; legendY: string = ''; seriesTitle: string = ''; chartTitle: string = ''; lastValueIsTotal: boolean = false;
									const labelsX: array of const; const labelsY: array of const);
	begin
		Draw (aChart, n, a, TDrawParameters.Create(legendX, legendY, seriesTitle, chartTitle, kNoLegendTitle, lastValueIsTotal, kNoScaleFactor, kNoOffsetX, labelsX, labelsY));
	end;

	procedure TGraphsForm.InputsCreate;
	begin
		with InputsList do begin
			Items.Clear;
			Items.Add('fecundability');
			Items.Add('definitive sterility');
			Items.Add('distrib fecundability');
			Items.Add('fecundability heterogeneity curve');
			Items.Add('intrauterine mortality risk');
			Items.Add('distrib intrauterine mortality risk');
			Items.Add('stillbirth mortality risk');
			ItemIndex := 0;
		end;
		InputsChange(self);
	end;

	procedure TGraphsForm.InputsChange(Sender: TObject);
	var
		i: longint;
		temp: array of double;
		range: array of longint;
		dp: TDrawParameters;
		simInd: longint = 4;
	begin
		Chart1.ClearSeries;
		case InputsList.ItemIndex of	//what entry (which item) has currently been chosen
			0: Draw(Chart1, 1, gFecundability,
				TDrawParameters.Create('Age in years', 'Monthly (lunar) probability', kNoSeriesTitle,
											'Fecundability: monthly (lunar) probability of pregnancy start'));
			1: begin
				setLength(range{%H-}, 1);
				range [0] := 11;
				dp := TDrawParameters.Create('Age in years', 'Probability of being sterile',
				'Pittinger & Wood', chartTitleFor ('Permanent sterility by age: ' + definitiveSterilityModelName,
											gHasObserved_definitive_sterility), kNoLegendTitle,
				kLastValueIsNotTotal, kNoScaleFactor);
				dp.rangeValuesX := range;
				Draw(Chart1, 1, gDefinitive_sterility_PW, dp);
				dp := TDrawParameters.Create('Age in years', 'Probability of being sterile',
				'Kinfert', chartTitleFor ('Permanent sterility by age: ' + definitiveSterilityModelName,
											gHasObserved_definitive_sterility), kNoLegendTitle,
				kLastValueIsNotTotal, kNoScaleFactor);
				dp.rangeValuesX := range;
				Draw(Chart1, 2, gDefinitive_sterility_Kinfert, dp);
				dp := TDrawParameters.Create('Age in years', 'Probability of being sterile',
				'Léridon', chartTitleFor ('Permanent sterility by age: ' + definitiveSterilityModelName,
											gHasObserved_definitive_sterility), kNoLegendTitle,
				kLastValueIsNotTotal, kNoScaleFactor);
				dp.rangeValuesX := range;
				Draw(Chart1, 3, gDefinitive_sterility_Leridon, dp);
				if
					g_GENPARAM.fixedParameters [noInitialSterility].state.value or
					g_GENPARAM.fixedParameters [fixedDefinitiveSterility].state.value then
				begin
					dp := TDrawParameters.Create('Age in years', 'Probability of being sterile',
					'Modified', chartTitleFor ('Permanent sterility by age: ' + definitiveSterilityModelName,
											gHasObserved_definitive_sterility), kNoLegendTitle,
											kLastValueIsNotTotal, kNoScaleFactor);
					dp.rangeValuesX := range;
					Draw(Chart1, 4, gDefinitive_sterility, dp);
					simInd := 5
				end else
                	simInd := 4;
				
				{whichever of the three models is in force is what the draws are read against}
				if gHasObserved_definitive_sterility then begin
					dp := TDrawParameters.Create('Age in years', 'Probability of being sterile',
					simulatedTitle (false), chartTitleFor ('Permanent sterility by age: ' +
											definitiveSterilityModelName, true), kNoLegendTitle,
					kLastValueIsNotTotal, kNoScaleFactor);
					dp.rangeValuesX := range;
					dp.markerStyle := psCircle;
					Draw(Chart1, simInd, gObserved_definitive_sterility, dp);
				end;
				setLength(range, 0);
			end;
			2: Draw(Chart1, 1, gDistrib_fecundability, 'Intervals between 0 and 1',
							'Proportion of women with relative level under interval', kNoSeriesTitle,
							'Cumulative distribution of fecundability across women (around mean level of: ' + floatToStr (gMean_fecundability) + ')');
			3: begin
				dp := TDrawParameters.Create('Fecundability probability', 'Proportion of women',
															'Theoretical', chartTitleFor ('Distribution of individual fecundability at age 22',
																			gHasObserved_fecundability), kNoLegendTitle,
															kLastValueIsNotTotal, kNoScaleFactor);
				dp.scaleFactorX := 1 / kMaxDistribFecundability;
				setLength (temp{%H-}, kMaxDistribFecundability+1);
				for i := 1 to kMaxDistribFecundability do begin
					temp[i] := gDistrib_fecundability[i] - gDistrib_fecundability[i-1];
				end;
				Draw(Chart1, 1, temp, dp);
				setLength (temp, 0);
				{and the levels the simulation drew, filled by reportFecundabilityCheck}
				if gHasObserved_fecundability then begin
					dp := TDrawParameters.Create('Fecundability probability', 'Proportion of women',
															simulatedTitle (false), chartTitleFor ('Distribution of individual fecundability at age 22', true),
															kNoLegendTitle, kLastValueIsNotTotal, kNoScaleFactor);
					dp.scaleFactorX := 1 / kMaxDistribFecundability;
					dp.markerStyle := psCircle;
					Draw(Chart1, 2, gDistrib_fecundability_simulated, dp);
				end;
			end;
			4: begin
				{Both alternative schedules, then the working array if a modifier has changed it,
				 then the proportion of the conceptions simulated at each age that ended in a
				 spontaneous abortion. Laid out like the permanent sterility chart above.}
				setLength(range, 2);
				range [0] := 11;
				range [1] := 58;
				dp := TDrawParameters.Create('Age in years', 'Probability of a natural abortion if pregnant',
													'Léridon [2004]', chartTitleFor ('Intrauterine mortality risk by age: ' +
																	intrauterineRiskModelName,
																	gHasObserved_intrauterine_risk), kNoLegendTitle,
													kLastValueIsNotTotal, kNoScaleFactor);
				dp.rangeValuesX := range;
				Draw(Chart1, 1, gIntrauterine_mortality_risk_Leridon, dp);
				dp := TDrawParameters.Create('Age in years', 'Probability of a natural abortion if pregnant',
													'Magnus [2019]', chartTitleFor ('Intrauterine mortality risk by age: ' +
																	intrauterineRiskModelName,
																	gHasObserved_intrauterine_risk), kNoLegendTitle,
													kLastValueIsNotTotal, kNoScaleFactor);
				dp.rangeValuesX := range;
				Draw(Chart1, 2, gIntrauterine_mortality_risk_Magnus, dp);
				if g_GENPARAM.fixedParameters [fixedIntrauterineMortality].state.value then begin
					dp := TDrawParameters.Create('Age in years', 'Probability of a natural abortion if pregnant',
													'Modified', chartTitleFor ('Intrauterine mortality risk by age: ' +
																	intrauterineRiskModelName,
																	gHasObserved_intrauterine_risk), kNoLegendTitle,
													kLastValueIsNotTotal, kNoScaleFactor);
					dp.rangeValuesX := range;
					Draw(Chart1, 3, gIntrauterine_mortality_risk, dp);
					simInd := 4
				end else
					simInd := 3;
				{whichever of the two schedules is in force is what the draws are read against}
				if gHasObserved_intrauterine_risk then begin
					dp := TDrawParameters.Create('Age in years', 'Probability of a natural abortion if pregnant',
													simulatedTitle (false), chartTitleFor ('Intrauterine mortality risk by age: ' +
																	intrauterineRiskModelName, true),
													kNoLegendTitle, kLastValueIsNotTotal, kNoScaleFactor);
					dp.rangeValuesX := range;
					dp.markerStyle := psCircle;
					Draw(Chart1, simInd, gObserved_intrauterine_risk, dp);
				end;
				setLength(range, 0);
			end;
			5: begin
				dp := TDrawParameters.Create('Lunar month of pregnancy terminated by a natural abortion',
											'Proportion of pregnancies with natural abortion', 'Theoretical',
											chartTitleFor ('Intrauterine mortality: the month a pregnancy is lost (Barrett)',
															gHasObserved_distrib_intrauterine), kNoLegendTitle,
											kLastValueIsNotTotal, kNoScaleFactor, kNoOffsetX, [0, 1, 2, 3, 4, 5, 6, 7, 8], []);
				Draw(Chart1, 1, gDistrib_intrauterine_mortality_risk, dp);
				if gHasObserved_distrib_intrauterine then begin
					dp := TDrawParameters.Create('Lunar month of pregnancy terminated by a natural abortion',
											'Proportion of pregnancies with natural abortion', simulatedTitle (true),
											chartTitleFor ('Intrauterine mortality: the month a pregnancy is lost (Barrett)', true),
											kNoLegendTitle, kLastValueIsNotTotal, kNoScaleFactor, kNoOffsetX, [0, 1, 2, 3, 4, 5, 6, 7, 8], []);
					dp.markerStyle := psCircle;
					Draw(Chart1, 2, gObserved_distrib_intrauterine, dp);
				end;
			end;
			6: begin
				{Both alternative schedules, then the working array if a modifier has changed it,
				 then the proportion of the conceptions simulated at each age that ended in a
				 stillbirth. Laid out like the permanent sterility chart above.}
				setLength(range, 2);
				range [0] := 11;
				range [1] := 58;
				dp := TDrawParameters.Create('Age in years', 'Probability of a stillbirth',
													'Barrett [1971]', chartTitleFor ('Stillbirth risk by age: ' +
																	stillbirthRiskModelName,
																	gHasObserved_stillbirth_risk), kNoLegendTitle,
													kLastValueIsNotTotal, kNoScaleFactor);
				dp.rangeValuesX := range;
				Draw(Chart1, 1, gStillbirth_mortality_risk_Barrett, dp);
				dp := TDrawParameters.Create('Age in years', 'Probability of a stillbirth',
													'United States 2023', chartTitleFor ('Stillbirth risk by age: ' +
																	stillbirthRiskModelName,
																	gHasObserved_stillbirth_risk), kNoLegendTitle,
													kLastValueIsNotTotal, kNoScaleFactor);
				dp.rangeValuesX := range;
				Draw(Chart1, 2, gStillbirth_mortality_risk_US2023, dp);
				if g_GENPARAM.fixedParameters [fixedIntrauterineMortality].state.value then begin
					dp := TDrawParameters.Create('Age in years', 'Probability of a stillbirth',
													'Modified', chartTitleFor ('Stillbirth risk by age: ' +
																	stillbirthRiskModelName,
																	gHasObserved_stillbirth_risk), kNoLegendTitle,
													kLastValueIsNotTotal, kNoScaleFactor);
					dp.rangeValuesX := range;
					Draw(Chart1, 3, gStillbirth_mortality_risk, dp);
					simInd := 4
				end else
					simInd := 3;
				{whichever of the two schedules is in force is what the draws are read against}
				if gHasObserved_stillbirth_risk then begin
					dp := TDrawParameters.Create('Age in years', 'Probability of a stillbirth',
													simulatedTitle (false), chartTitleFor ('Stillbirth risk by age: ' +
																	stillbirthRiskModelName, true),
													kNoLegendTitle, kLastValueIsNotTotal, kNoScaleFactor);
					dp.rangeValuesX := range;
					dp.markerStyle := psCircle;
					Draw(Chart1, simInd, gObserved_stillbirth_risk, dp);
				end;
				setLength(range, 0);
			end;
		end;
	end;

	procedure TGraphsForm.InputsEnter(Sender: TObject);
	begin
		OKFixedInputs.Default := true;
	end;

	procedure TGraphsForm.InputsClose(Sender: TObject);
	begin
		OKFixedInputs.Default := false;
	end;

	procedure TGraphsForm.InputsVarCreate;
	begin
		with InputsVarList do begin
			Items.Clear;
			Items.Add('Waiting time after first union');
			Items.Add('Waiting time after union');
			Items.Add('Waiting time after first birth');
			Items.Add('Waiting time after second birth');
			Items.Add('Amenorrhea temporary sterility');
			Items.Add('Mortality survival function');
			Items.Add('First Union survival function');
			Items.Add('Separation risk');
			Items.Add('Separation survival function');
			Items.Add('Second Union risk');
			Items.Add('Risk age union men per age union women');
			Items.Add('Risk age union women per age union men');
			Items.Add('Cumul age union men per age union women');
			Items.Add('Cumul age union women per age union men');
			ItemIndex := 0;
		end;
		InputsVarChange(self);
	end;

	procedure TGraphsForm.InputsVarChange(Sender: TObject);
	var
		ageUnion: longint;
		nS: longint;	{series drawn so far. Draw creates a series only when it is asked for the
						 one just after the last, so a curve that is skipped must not leave a hole}
		dp: TDrawParameters;
	begin
		Chart2.ClearSeries;
		case InputsVarList.ItemIndex of	//what entry (which item) has currently been chosen
			0:	Draw(Chart2, 1, prop_pDemReg^.AccDurationContrAfterUnion,
						'Lunar months after first union (mean waiting time: ' +
						doubleToMinStringHelper (prop_pDemReg^.dp[meanTimeContraceptionAfterUnionHigh].value) +
						' years for ' +
						doubleToMinStringHelper (prop_pDemReg^.dp[propContraceptionAfterUnion].value * 100) +
						'% of women)',
						'Monthly (lunar) probability of NOT using contraception', kNoSeriesTitle);
			1:	Draw(Chart2, 1, prop_pDemReg^.AccDurationWaitingTime[0],
						'Lunar months after union (mean waiting time: ' +
						doubleToMinStringHelper (prop_pDemReg^.meanTimeSpacing.value[0]) +
						' years for ' +
						doubleToMinStringHelper (prop_pDemReg^.effSpacing.value[0] * 100) +
						'% of women)',
						'Monthly (lunar) probability of NOT using contraception', kNoSeriesTitle);
			2:	Draw(Chart2, 1, prop_pDemReg^.AccDurationWaitingTime[1],
						'Lunar months after first birth (mean waiting time: ' +
						doubleToMinStringHelper (prop_pDemReg^.meanTimeSpacing.value[1]) +
						' years for ' +
						doubleToMinStringHelper (prop_pDemReg^.effSpacing.value[1] * 100) +
						'% of women)',
						'Monthly (lunar) probability of NOT using contraception', kNoSeriesTitle);
			3:	Draw(Chart2, 1, prop_pDemReg^.AccDurationWaitingTime[1],
						'Lunar months after second (mean waiting time: ' +
						doubleToMinStringHelper (prop_pDemReg^.meanTimeSpacing.value[1]) +
						' years for ' +
						doubleToMinStringHelper (prop_pDemReg^.effSpacing.value[1] * 100) +
						'% of women)',
						'Monthly (lunar) probability of NOT using contraception', kNoSeriesTitle);
			{Three curves, because the model is relational. gSchedule_temporary_sterility is the
			 standard of Lesthaeghe and Page, the same in every run; the cohort selected above
			 derives its own schedule from it with its AMENO_ALPHA and AMENO_BETA, and that is what
			 its women draw from, so it is the theoretical curve here. The standard is drawn in
			 black behind the two, to show what the two parameters did to it. The simulated curve
			 belongs to the last setting simulated, which its legend entry says.}
			4:	begin
					dp := TDrawParameters.Create('Lunar months after end of pregnancy',
										'Probability of being temporary sterile (amenorrhea post partum)',
										'Theoretical',
										chartTitleFor ('Amenorrhea: the Lesthaeghe and Page schedule of this cohort',
														gHasObserved_temporary_sterility), kNoLegendTitle,
										kLastValueIsNotTotal, kNoScaleFactor);
					nS := 1;
					Draw(Chart2, nS, prop_pDemReg^.temporary_sterility, dp);
					if gHasObserved_temporary_sterility then begin
						dp := TDrawParameters.Create('Lunar months after end of pregnancy',
											'Probability of being temporary sterile (amenorrhea post partum)',
											simulatedTitle (true),
											chartTitleFor ('Amenorrhea: the Lesthaeghe and Page schedule of this cohort', true),
											kNoLegendTitle, kLastValueIsNotTotal, kNoScaleFactor);
						dp.markerStyle := psCircle;
						Inc (nS);
						Draw(Chart2, nS, gObserved_temporary_sterility, dp);
					end;
					dp := TDrawParameters.Create('Lunar months after end of pregnancy',
										'Probability of being temporary sterile (amenorrhea post partum)',
										'Lesthaeghe-Page standard',
										chartTitleFor ('Amenorrhea: the Lesthaeghe and Page schedule of this cohort',
														gHasObserved_temporary_sterility), kNoLegendTitle,
										kLastValueIsNotTotal, kNoScaleFactor);
					Inc (nS);
					Draw(Chart2, nS, gSchedule_temporary_sterility, dp);
					setSeriesColor (Chart2, nS, clBlack);
				end;
			5:	begin
					Draw(Chart2, 1, prop_pDemReg^.mortalityInfo.survival_men,
								'Age in years',
								'Probability of being alive', 'men');
					Draw(Chart2, 2, prop_pDemReg^.mortalityInfo.survival_women,
								'Age in years',
								'Probability of being alive', 'women');
				end;
			6:	begin
					Draw(Chart2, 1, prop_pDemReg^.pCurrUnionInfo^.prop_cel_men,
								TDrawParameters.Create(
														'Age in years',
														'Probability of not having entered a first union',
														'men',
														kNoChartTitle,
														kNoLegendTitle,
														kLastValueIsNotTotal, kNoScaleFactor, kNoOffsetX,
														[],
														[0, 0.05,
														0.1, 0.15,
														0.2, 0.25,
														0.3, 0.35,
														0.4, 0.45,
														0.5, 0.55,
														0.6, 0.65,
														0.7, 0.75,
														0.8, 0.85,
														0.9, 0.95,
														1]
								)
					);
					Draw(Chart2, 2, prop_pDemReg^.pCurrUnionInfo^.prop_cel_women,
								TDrawParameters.Create(
														'Age in years',
														'Probability of not having entered a first union',
														'women',
														kNoChartTitle,
														kNoLegendTitle,
														kLastValueIsNotTotal, kNoScaleFactor, kNoOffsetX,
														[],
														[0, 0.05,
														0.1, 0.15,
														0.2, 0.25,
														0.3, 0.35,
														0.4, 0.45,
														0.5, 0.55,
														0.6, 0.65,
														0.7, 0.75,
														0.8, 0.85,
														0.9, 0.95,
														1]
								)
					);
				end;
			7:	Draw(Chart2, 1, prop_pDemReg^.separationInfo.cumul_separation,
						'Lunar months after start of union',
						'Probability of being separated', kNoSeriesTitle);
			8:	Draw(Chart2, 1, prop_pDemReg^.pCurrUnionInfo^.prop_not_repartnering, 'Duration in years (for individuals who start a new union)', 'Probability of being still separated', kNoSeriesTitle, 'Survival function from end of union to start of following one');
			9:	begin
					Draw(Chart2, 1, prop_pDemReg^.pCurrUnionInfo^.prop_repartnering[man],
							'Age in years',
							'Probability', 'men');
					Draw(Chart2, 2, prop_pDemReg^.pCurrUnionInfo^.prop_repartnering[woman],
							'Age in years',
							'Probability', 'women', 'Probability of forming a second union, by age at separation');
				end;
			10: for ageUnion := 13 to 42 do
					Draw(Chart2, ageUnion - 12, prop_pDemReg^.pCurrUnionInfo^.union_women_men[ageUnion, normal],
							TDrawParameters.Create('Age in years',
							'Probability', IntToStr(ageUnion), 'Risk of union of men by age at union of women', 'Age at union of women', kLastValueIsNotTotal));
			11: for ageUnion := 15 to 44 do
					Draw(Chart2, ageUnion - 14, prop_pDemReg^.pCurrUnionInfo^.union_men_women[ageUnion, normal],
							TDrawParameters.Create('Age in years',
							'Probability', IntToStr(ageUnion), 'Risk of union of women by age at union of men', 'Age at union of men', kLastValueIsNotTotal));
			12: for ageUnion := 13 to 42 do
					Draw(Chart2, ageUnion - 12, prop_pDemReg^.pCurrUnionInfo^.union_women_men[ageUnion, aggregated],
							TDrawParameters.Create('Age in years',
							'Probability', IntToStr(ageUnion), 'Cumulated risk of union of men by age at union of women', 'Age at union of women', kLastValueIsNotTotal));
			13: for ageUnion := 15 to 44 do
					Draw(Chart2, ageUnion - 14, prop_pDemReg^.pCurrUnionInfo^.union_men_women[ageUnion, aggregated],
							TDrawParameters.Create('Age in years',
							'Probability', IntToStr(ageUnion), 'Cumulated risk of union of women by age at union of men', 'Age at union of men', kLastValueIsNotTotal));


		end;
	end;

	procedure TGraphsForm.InputsVarEnter(Sender: TObject);
	begin
		OKVariableInputs.Default := true;
	end;

	procedure TGraphsForm.InputsVarClose(Sender: TObject);
	begin
		OKVariableInputs.Default := false;
	end;

	procedure TGraphsForm.InputsVarCohortsCreate;
	var
		 ind, selItem: longint;
	begin
		prop_currCohort := DemRegimeCollection_firstCohort;
		DemRegimeCollection_yearsReadInConfig (prop_cohorts);
		
		InputsVarCohorts.Items.Clear;
		selItem := 0;
		for ind := 0 to high(prop_cohorts) do begin
				InputsVarCohorts.Items.Add(intToStr(prop_cohorts[ind]));
				if prop_cohorts[ind] = prop_currCohort then
					 selItem := ind;
		end;
		InputsVarCohorts.ItemIndex := selItem;

		InputsVarCohortsChange(self);
	end;

	procedure TGraphsForm.InputsVarCohortsChange(Sender: TObject);
	begin
		prop_currCohort := prop_cohorts[InputsVarCohorts.ItemIndex];
		prop_pDemReg := getCohort_p (prop_currCohort);
		self.InputsVarChange (Sender);
	end;

	procedure TGraphsForm.SimulationStatusEnter(Sender: TObject);
	const
		kNoResult = 'Simulation not run. No results';
	var
		runMsg, runMsgOutput, runMsgOutputKinship: string;
	begin
		if KinFertForm.simulationRan then begin
			runMsg := 'Simulation done. Values of run: ' + IntToStr (g_nRuns) + ', name: ' + g_FileName.value;
			runMsgOutput := 'Number of simulations: ' + IntToStr (g_nRuns);
			if g_nRuns_aggrKinship > 0 then
					runMsgOutputKinship := 'Number of simulations: ' + IntToStr (g_nRuns_aggrKinship)
			else
					runMsgOutputKinship := kNoResult;
		end
		else begin
			runMsg := 'Simulation not run. Using default values';
			runMsgOutput := kNoResult;
			runMsgOutputKinship := kNoResult;
		end;
		SimulationStatus.caption := runMsg;
		SimulationStatusOutputs.caption := runMsgOutput;
		SimulationStatusOutputsKinship.caption := runMsgOutputKinship;
	end;

	procedure TGraphsForm.OutputsCreate;
	begin
		with OutputsList do begin
			Items.Clear;
			Items.Add('Interval union - first conception');
			Items.Add('Interval first - second conception');
			Items.Add('Interval second - third conception');
			ItemIndex := 0;
		end;
		OutputsChange(self);
	end;

	procedure TGraphsForm.OutputsChange(Sender: TObject);
	var
		ind: longint;
		initScaleFactor: double;
	begin
		if g_nRuns > 0 then begin
			// we plot only if we have simulation results
			Chart3.ClearSeries;
			initScaleFactor := 1000;
			case OutputsList.ItemIndex of	//what entry (which item) has currently been chosen
				0:	for ind := 0 to g_nRuns-1 do
						Draw(Chart3, ind+1, gOut_intervals_between_conceptions[ind, 0],
						TDrawParameters.Create('Lunar months', 'Prop conceptions (per 1000)', kNoSeriesTitle,
						'Interval between first union and first conception (per Thousands)', 'Simulation number', kLastValueIsTotal, initScaleFactor));
				1:	for ind := 0 to g_nRuns-1 do
						Draw(Chart3, ind+1, gOut_intervals_between_conceptions[ind, 1],
						TDrawParameters.Create('Lunar months', 'Prop conceptions (per 1000)', kNoSeriesTitle,
						'Interval between first birth and subsequent conception (per Thousands)', 'Simulation number', kLastValueIsTotal, initScaleFactor));
				2:	for ind := 0 to g_nRuns-1 do
						Draw(Chart3, ind+1, gOut_intervals_between_conceptions[ind, 2],
						TDrawParameters.Create('Lunar months', 'Prop conceptions (per 1000)', kNoSeriesTitle,
						'Interval between second birth and subsequent conception (per Thousands)', 'Simulation number', kLastValueIsTotal, initScaleFactor));
			end;
		end;
	end;

	procedure TGraphsForm.OutputsEnter(Sender: TObject);
	begin
		OKOutputFertility.Default := true;
	end;

	procedure TGraphsForm.OutputsClose(Sender: TObject);
	begin
		OKOutputFertility.Default := false;
	end;

	procedure TGraphsForm.OutputsKinshipCreate;
	begin
		with OutputsKinshipList do begin
			Items.Clear;
			Items.Add('Age distribution of surviving kin');
			Items.Add('Number of surviving kin during ego''s life');
			ItemIndex := 0;
		end;
		OutputsKinshipChange(self);
	end;

	function lengthSetAges (aSet: SetAges): longint;
	begin
		result := lengthSet (SetChars(aSet));
	end;

	function elementInSetAges (aSet: SetAges; index: longint): agesLife;
	begin
		result := agesLife ( elementInSet (SetChars (aSet), index) );
	end;

	procedure TGraphsForm.OutputsKinshipChange(Sender: TObject);
	var
		typeOfKin: KinTypes;
		aSexT: SexTotal;
		ageEgo, ageEgoInd: longint;

		ind, ind2, highTable: longint;
		totKin: double;
		a: array of double;
		chartTitle: string;
		nSimulationShown: longint = 4;
		startSims: longint;
  		verticalLine: TConstantLine;
	begin
		startSims := max (0, (g_nRuns_aggrKinship - nSimulationShown));
		ageEgoInd := AgeKinshipList.ItemIndex;
		ageEgo := elementInSetAges (kSetAgesEgo, ageEgoInd);
		typeOfKin := KinTypes (KinTypesList.ItemIndex+2);
		aSexT := SexTotal (SexList.ItemIndex);

		case OutputsKinshipList.ItemIndex of	//what entry (which item) has currently been chosen
			0: begin
				ageEgoLab.visible := true;
				ageKinshipList.visible := true;
				chartTitle := 'Age distribution of ';
				if typeOfKin = kt_total then
					chartTitle := chartTitle + 'kin'
				else
					chartTitle := chartTitle + str_kinship[typeOfKin];
				chartTitle := chartTitle + ' at ego''s';
				if ageEgoInd = 0 then
					chartTitle := chartTitle + ' birth'
				else begin
					chartTitle := chartTitle + ' age: ' + IntToStr(ageEgo);
				end;
				case aSexT of
					men: chartTitle := chartTitle + ' (male egos)';
					women: chartTitle := chartTitle + ' (females egos)';
					all: chartTitle := chartTitle + ' (egos of both sexes)';
				end;
			end;
			1: begin
				ageEgoLab.visible := false;
				ageKinshipList.visible := false;
				chartTitle := 'Mean number of surviving kin: ';
				chartTitle := chartTitle + str_kinship[typeOfKin];
				case aSexT of
					men: chartTitle := chartTitle + ' (male egos)';
					women: chartTitle := chartTitle + ' (females egos)';
					all: chartTitle := chartTitle + ' (egos of both sexes)';
				end;
			end
		end;

		if g_nRuns_aggrKinship > 0 then begin
			// we plot only if we have simulation results
			Chart4.ClearSeries;

			case OutputsKinshipList.ItemIndex of	//what entry (which item) has currently been chosen
				0: begin
					// Create a vertical line for age ego
					verticalLine := TConstantLine.Create(self);
					verticalLine.Position := ageEgo;
					verticalLine.Pen.Color := clRed;
					verticalLine.Pen.Width := 5;
					verticalLine.Pen.Style := psDash; // Set the line style to dash
    				verticalLine.LineStyle := lsVertical;
					verticalLine.Legend.Visible := false;
					Chart4.AddSeries(verticalLine);
					
					highTable := high(gOut_totKinship[0, ageEgoInd, all, alive, typeOfKin]);
					setLength (a{%H-}, highTable);
					for ind := startSims to g_nRuns_aggrKinship - 1 do begin
						totKin := 0;
						for ind2 := 0 to (kMaxAgeLife-1) do begin
							if (gOut_totKinship[ind, ageEgoInd, aSexT, alive, kt_ego, ageEgo] > 0) then begin
								a[ind2] := 	gOut_totKinship[ind, ageEgoInd, aSexT, alive, typeOfKin, ind2] /
											gOut_totKinship[ind, ageEgoInd, aSexT, alive, kt_ego, ageEgo];
							end else a[ind2] := 0;
							totKin := totKin + a[ind2];
							end;
						Draw(Chart4, 1 + (ind - startSims)*2+1, a,
							TDrawParameters.Create(
												'Age in years',
												'Number of kin',
												IntToStr (ind+1) + ': ALIVE (Total: ' + doubleToMinStringHelper(totKin) + ')',
							chartTitle, 'Simulation number', kLastValueIsNotTotal)
							);
						totKin := 0;
						for ind2 := 0 to (kMaxAgeLife-1) do begin
							if (gOut_totKinship[ind, ageEgoInd, aSexT, alive, kt_ego, ageEgo] > 0) then begin
								a[ind2] := 	gOut_totKinship[ind, ageEgoInd, aSexT, born, typeOfKin, ind2] /
											gOut_totKinship[ind, ageEgoInd, aSexT, alive, kt_ego, ageEgo];
							end else a[ind2] := 0;
							totKin := totKin + a[ind2];
						end;
						Draw(Chart4, 1 + (ind - startSims)*2+2, a,
							TDrawParameters.Create('Age in years', 'Number of kin', IntToStr (ind+1) + ': BORN (Total: ' + doubleToMinStringHelper(totKin) + ')',
							chartTitle, 'Simulation number', kLastValueIsNotTotal)
							);
					end;
					
					setLength (a, 0);
				end;
				1: begin
					highTable := High (agesLife);
					setLength (a, highTable);
					for ind := startSims to g_nRuns_aggrKinship - 1 do begin
						for ind2 := 0 to (kMaxAgeLife-1) do begin
							if g_NumKinByAgeEgo[ind, aSexT, ind2, kt_ego] > 3 then
								a[ind2] := 	g_NumKinByAgeEgo[ind, aSexT, ind2, typeOfKin] /
											g_NumKinByAgeEgo[ind, aSexT, ind2, kt_ego]
							else
								a[ind2] := NaN;
						end;
						Draw(Chart4, (ind - startSims)+1, a,
							TDrawParameters.Create(
												'Age of ego',
												'Mean number of kin',
												IntToStr (ind+1),
							chartTitle, 'Simulation number', kLastValueIsNotTotal)
							);
					end;
					setLength (a, 0);
				end;
			end; {case}
		end;
	end;

	procedure TGraphsForm.OutputsKinshipEnter(Sender: TObject);
	begin
		OKOutputKinship.Default := True;
	end;

	procedure TGraphsForm.OutputsKinshipClose(Sender: TObject);
	begin
		OKOutputKinship.Default := False;
	end;

	procedure TGraphsForm.AgeKinshipCreate;
	var
		ageEgoInd: longint;
	begin
		with AgeKinshipList do begin
			Items.Clear;
			for ageEgoInd := 0 to lengthSetAges(kSetAgesEgo)-1 do
				Items.Add(IntToStr(elementInSetAges (kSetAgesEgo, ageEgoInd)));
			ItemIndex := 0;
		end;
	end;

	procedure TGraphsForm.KinTypesCreate;
	var
		typeOfKin: KinTypes;
	begin
		with KinTypesList do begin
			Items.Clear;
			for typeOfKin := kt_partner to kt_total do
				Items.Add(str_kinship[typeOfKin]);
			ItemIndex := Items.Count - 1;
		end;
	end;

	procedure TGraphsForm.SexCreate;
	begin
		with SexList do begin
			Items.Clear;
			Items.Add('Men');
			Items.Add('Women');
			Items.Add('All');
			ItemIndex := Items.Count - 1;
		end;
	end;

	procedure TGraphsForm.AgeKinshipChange(Sender: TObject);
	begin
		OutputsKinshipChange(Sender);
	end;

	procedure TGraphsForm.KinTypesChange(Sender: TObject);
	begin
		OutputsKinshipChange(Sender);
	end;

	procedure TGraphsForm.SexChange(Sender: TObject);
	begin
		OutputsKinshipChange(Sender);
	end;

// >>> Claude 2026-09-12 start
	{The Children-Grooms tab, rebuilt.

	 One question is asked here, and these charts exist to answer it: does the pre-simulation
	 provide enough candidates? Two searches depend on it. A child, or an ascendant of a child,
	 asks the birth index for a mother who gave birth in the child's own cohort. A man asks the
	 bride index for a woman of the cohort and the age at union his own cohort implies. When the
	 cell asked for is empty the search moves to a neighbouring one, so a relative is still
	 produced, but from a cohort or an age at union other than the one the model called for.
	 The share of searches that had to move IS the answer, and everything else that used to be
	 on this tab was a step on the way to it.

	 Four entries. The first is the answer, both searches on one chart. The next two split it by
	 generation, since the ascendants are looked up in cohorts well before ego's and it is
	 useful to know which generation is short of candidates. The fourth is the other side of the
	 same coin: unions the simulation produced that the groom index could not hold at all, which
	 is a loss before any search is made.

	 What was removed: the counts of lookups by cohort and generation, fourteen entries of them,
	 which said where the searches fell but not whether they succeeded, and the mean distance in
	 years of a search that missed, which is now in the memo and in verification.txt where it
	 can be read as a number instead of estimated off a chart.}
	const
		kItemSearchBoth = 0;
		kItemMotherByGeneration = 1;
		kItemBrideByGeneration = 2;
		kItemUnionsOffered = 3;

	procedure TGraphsForm.ChildGroomCreate;
	begin
		with ChildGroomList do begin
			Items.Clear;
			Items.Add('Searches that did not find their candidate');
			Items.Add('Mother search, by generation');
			Items.Add('Bride search, by generation');
			Items.Add('Unions produced, by groom cohort');
			ItemIndex := 0;
		end;
		ChildGroomChange(self);
	end;
// <<< Claude 2026-09-12 end

	function cLabelsX (minVal, maxVal: longint): arrayOfDouble;
	var
		n, int, first, last, ind, val: longint;

	begin
		first := trunc ((minVal - kStateRangeLengthLimit) / 10) * 10;
		last := trunc ((maxVal + kStateRangeLengthLimit) / 10) * 10;
		int := 10;
		last := trunc (last / int);
		first := trunc (first / int);
		n := last - first + 1;
		setLength (result{%H-}, n);
		ind := 0;
		for val := first to last do begin
			result[ind] := val * int;
			inc (ind);
		end;
	end;

// >>> Claude 2026-09-12 start
	{Decades covering [first, last], for a chart drawn over an arbitrary span of cohorts.
	 cLabelsX above always widens by kStateRangeLengthLimit on each side, which these charts
	 cannot use because they trim the span they draw.}
	function cLabelsXSpan (first, last: longint): arrayOfDouble;
	var
		n, ind, val, firstTen, lastTen: longint;
	begin
		firstTen := floor (first / 10.0);
		lastTen := ceil (last / 10.0);
		n := lastTen - firstTen + 1;
		if (n < 1) then n := 1;
		setLength (result{%H-}, n);
		ind := 0;
		for val := firstTen to firstTen + n - 1 do begin
			result[ind] := val * 10;
			Inc (ind);
		end;
	end;

	{The share of searches, in per cent by cohort, that had to be answered from a cell other
	 than the one asked for, over the cohorts where a search was made. Returns the span drawn
	 so that the caller can label the axis, and zero when no search was recorded.

	 A cohort where no search at all was made is left out of the curve rather than drawn as a
	 zero, since zero out of zero is not a share of nothing: it is not a measurement. TAChart
	 draws a straight segment across a gap, which is the right reading here: the curve is an
	 estimate over the cohorts that carry searches.}
	function TGraphsForm.addSearchCurve (const total, miss: array of arrayOfLongint;
								seriesTitle: string;
								firstCohort, marginBelow, generation, n: longint;
								out firstDrawn, lastDrawn, nSearches, nMissed: longint;
								out worstPct: double): boolean;
	var
		dp: TDrawParameters;
		xs, ys: array of double;
		gen, genRow, i, nCohorts, nPoints: longint;
		tot, bad: longint;
	begin
		result := false;
		firstDrawn := 0;
		lastDrawn := 0;
		nSearches := 0;
		nMissed := 0;
		worstPct := 0.0;
		if (length (total) = 0) then exit;
		nCohorts := length (total [0]);
		setLength (xs{%H-}, nCohorts);
		setLength (ys{%H-}, nCohorts);
		nPoints := 0;
		for i := 0 to nCohorts - 1 do begin
			tot := 0;
			bad := 0;
			for gen := kMinKinGeneration to kMaxKinGeneration do begin
				genRow := kinGenerationRow (gen);
				if (genRow >= length (total)) then continue;
				{generation 0 means every generation at once}
				if (generation <> 0) and (gen <> generation) then continue;
				tot := tot + total [genRow, i];
				bad := bad + miss [genRow, i];
			end;
			if (tot = 0) then continue;
			nSearches := nSearches + tot;
			nMissed := nMissed + bad;
			xs [nPoints] := firstCohort - marginBelow + i;
			ys [nPoints] := 100.0 * bad / tot;
			if (ys [nPoints] > worstPct) then worstPct := ys [nPoints];
			Inc (nPoints);
		end;
		if (nPoints = 0) then exit;
		firstDrawn := trunc (xs [0]);
		lastDrawn := trunc (xs [nPoints - 1]);
		setLength (xs, nPoints);
		setLength (ys, nPoints);

		dp := TDrawParameters.Create ('Birth cohort', 'Per cent of searches answered from another cell');
		dp.seriesTitle := seriesTitle;
		dp.offsetLabelX := 0;
		{A curve that never leaves zero is the outcome one wants, and a plain line on the floor
		 of the frame reads as an empty chart. Markers make it visible as a measurement that ran
		 and found nothing, which is not the same thing as no measurement at all. A curve that
		 does leave zero is drawn plain, since it has a shape of its own to show.}
		if (worstPct = 0.0) then
			dp.markerStyle := psCircle;
		Draw (Chart5, n, ys, dp);
		setSeriesXY (Chart5, n, xs, ys);
		dp.Free;
		setLength (xs, 0);
		setLength (ys, 0);
		result := true;
	end;

	{The sentence that says what the chart shows, put in the title so that a run in which
	 nothing went wrong says so rather than showing a blank frame.}
	function TGraphsForm.searchSummary (nSearches, nMissed: longint): string;
	begin
		if (nSearches = 0) then
			result := 'no search recorded'
		else if (nMissed = 0) then
			result := IntToStr (nSearches) + ' searches, every one found the cell it asked for'
		else
			result := IntToStr (nSearches) + ' searches, ' + IntToStr (nMissed) +
					' answered from another cell (' +
					str_float (100.0 * nMissed / nSearches) + ' per cent)';
	end;

	{What to draw when no search at all was recorded, which is a state worth naming: the counts
	 are filled while the kinship is being built, so a run that built no kinship leaves them
	 empty, and so does a graph window opened before the first run.}
	procedure TGraphsForm.noSearchRecorded (what: string);
	var
		dp: TDrawParameters;
	begin
		dp := TDrawParameters.Create ('Birth cohort', 'Per cent of searches answered from another cell');
		dp.chartTitle := what + ': no search was recorded. These counts are filled while the ' +
					'kinship is built, so a run without kinship, or a window opened before the ' +
					'first run, leaves them empty';
		Draw (Chart5, 1, [0.0], dp);
		dp.Free;
	end;

	{Replaces the points Draw wrote with the real cohorts on the x axis, so that a curve with
	 gaps in it lands on the right years. Draw lays its points out at consecutive x values plus
	 one offset, which cannot express a gap.}
	procedure TGraphsForm.setSeriesXY (aChart: TChart; n: longint; const xs, ys: array of double);
	var
		i: longint;
		serie: TLineSeries;
	begin
		if (n < 1) or (n > aChart.SeriesCount) then exit;
		serie := TLineSeries (aChart.Series [n-1]);
		serie.Clear;
		for i := 0 to high (xs) do
			serie.AddXY (xs [i], ys [i]);
	end;

	{Entry 0: the answer, both searches on one chart. A curve on the floor says the
	 pre-simulation has a candidate for every search, and it carries markers so that it cannot
	 be mistaken for an empty chart; a curve that lifts says the candidates run out, and where.
	 The title carries the counts either way.}
	procedure TGraphsForm.drawSearchBoth;
	var
		n, f, l, first, last, nS, nM: longint;
		worst, worstAll: double;
		title: string;
		drewOne: boolean;
	begin
		Chart5.ClearSeries;
		n := 0;
		first := 0;
		last := 0;
		worstAll := 0.0;
		drewOne := false;
		if addSearchCurve (gMotherSearch, gMotherSearchMiss, 'mother search',
				gFirstCohortAncestorsChildren, gChildStateMarginBelow, 0, n + 1,
				f, l, nS, nM, worst) then begin
			Inc (n);
			first := f;
			last := l;
			drewOne := true;
			if (worst > worstAll) then worstAll := worst;
			title := 'Mother: ' + searchSummary (nS, nM);
		end else
			title := 'Mother: no search recorded';
		if addSearchCurve (gBrideSearch, gBrideSearchMiss, 'bride search',
				gFirstCohortGrooms, gGroomStateMarginBelow, 0, n + 1,
				f, l, nS, nM, worst) then begin
			Inc (n);
			if not drewOne then begin
				first := f;
				last := l;
			end else begin
				if (f < first) then first := f;
				if (l > last) then last := l;
			end;
			drewOne := true;
			if (worst > worstAll) then worstAll := worst;
			title := title + '.  Bride: ' + searchSummary (nS, nM);
		end else
			title := title + '.  Bride: no search recorded';
		if not drewOne then begin
			noSearchRecorded ('Searches that did not find their candidate');
			exit;
		end;
		setChart5Axis ('Searches that did not find their candidate. ' + title,
				'Birth cohort', 'Per cent of searches answered from another cell',
				first, last, worstAll);
	end;

	{Entries 1 and 2: the same measure, one curve per generation, so that a shortage can be
	 attributed to the generation it belongs to. The ascendants are looked up in cohorts one,
	 two and three mean ages at childbearing before ego's, which is where an index that is too
	 narrow shows first.}
	procedure TGraphsForm.drawSearchByGeneration (const total, miss: array of arrayOfLongint;
								what: string;
								firstCohort, lastCohort, marginBelow, marginAbove: longint);
	var
		gen, n, f, l, first, last, nS, nM, totS, totM: longint;
		worst, worstAll: double;
		drewOne: boolean;
	begin
		Chart5.ClearSeries;
		n := 0;
		first := 0;
		last := 0;
		totS := 0;
		totM := 0;
		worstAll := 0.0;
		drewOne := false;
		for gen := kMaxKinGeneration downto kMinKinGeneration do
			if addSearchCurve (total, miss, str_kinGeneration [gen],
					firstCohort, marginBelow, gen, n + 1, f, l, nS, nM, worst) then begin
				Inc (n);
				if not drewOne then begin
					first := f;
					last := l;
				end else begin
					if (f < first) then first := f;
					if (l > last) then last := l;
				end;
				drewOne := true;
				totS := totS + nS;
				totM := totM + nM;
				if (worst > worstAll) then worstAll := worst;
			end;
		if not drewOne then begin
			noSearchRecorded (what);
			exit;
		end;
		setChart5Axis (what + ', by generation. ' + searchSummary (totS, totM) +
					'. Index cohorts ' + IntToStr (firstCohort) + ' to ' + IntToStr (lastCohort),
				'Birth cohort', 'Per cent of searches answered from another cell',
				first, last, worstAll);
	end;

	{Entry 3: the write side. Every union the simulation produced, by the groom's birth cohort,
	 with the two edges of the groom index drawn as vertical lines. Anything outside them is a
	 union the index could not hold at all, which is a loss before any search is made, and a
	 different quantity from a search that had to move.}
	procedure TGraphsForm.drawUnionsByGroomCohort;
	var
		dp: TDrawParameters;
		col: array of longint;
		band, i, nCohorts: longint;
		edge: TConstantLine;
	begin
		Chart5.ClearSeries;
		nCohorts := length (gStateGroomsByAge);
		if (nCohorts = 0) then begin
			dp := TDrawParameters.Create ('Groom birth cohort', 'Unions');
			dp.chartTitle := 'Unions produced, by groom cohort: no run yet';
			Draw (Chart5, 1, [0.0], dp);
			dp.Free;
			exit;
		end;
		setLength (col{%H-}, nCohorts);
		for i := 0 to nCohorts - 1 do begin
			col [i] := 0;
			for band := 0 to kNbGroomAgeBands - 1 do
				col [i] := col [i] + gStateGroomsByAge [i, band];
		end;
		dp := TDrawParameters.Create ('Groom birth cohort (the end points hold everything further out)',
									'Unions produced');
		dp.chartTitle := 'Unions produced, by groom cohort. ' + IntToStr (gGroomCohortSkipped) +
					' of ' + IntToStr (gGroomUnionsSeen) + ' fell outside the index, which holds ' +
					IntToStr (gFirstCohortGrooms) + ' to ' + IntToStr (gLastCohortGrooms);
		dp.offsetLabelX := gFirstCohortGrooms - kStateRangeLengthLimit;
		dp.labelsX := cLabelsXSpan (gFirstCohortGrooms - kStateRangeLengthLimit,
					gFirstCohortGrooms - kStateRangeLengthLimit + nCohorts - 1);
		DrawIntegers (Chart5, 1, col, dp);
		dp.Free;
		setLength (col, 0);

		for i := 0 to 1 do begin
			edge := TConstantLine.Create (self);
			edge.LineStyle := lsVertical;
			if (i = 0) then begin
				edge.Position := gFirstCohortGrooms;
				edge.Title := 'first cohort in the index';
			end else begin
				edge.Position := gLastCohortGrooms;
				edge.Title := 'last cohort in the index';
			end;
			edge.Pen.Color := clBlack;
			edge.Pen.Width := 2;
			edge.Pen.Style := psDash;
			Chart5.AddSeries (edge);
		end;
	end;

	{The axis captions, the title and the vertical range, set once after the curves are drawn.
	 Draw takes them from the parameters of each curve, which is awkward when the curves carry
	 their own x values, so they are set here instead.

	 The vertical range is forced to start at zero and to be at least one per cent tall. Left to
	 itself the chart would fit the range to the data, and a run in which nothing missed would
	 draw a flat line squeezed onto the frame, which is what an empty chart looks like.}
	procedure TGraphsForm.setChart5Axis (title, labelX, labelY: string; first, last: longint;
								yMax: double);
	var
		axis: TChartAxis;
		src: TListChartSource;
		labels: arrayOfDouble;
		i: longint;
	begin
		if (Chart5.Title.Text.Count > 0) then begin
			Chart5.Title.Text.Strings[0] := title;
			Chart5.Title.Font.Size := 14;
			Chart5.Title.Visible := true;
		end;
		Chart5.LeftAxis.Title.caption := labelY;
		Chart5.LeftAxis.Title.visible := true;
		Chart5.LeftAxis.visible := true;
		if (yMax < 1.0) then yMax := 1.0;
		Chart5.LeftAxis.Range.Min := 0.0;
		Chart5.LeftAxis.Range.Max := yMax * 1.1;
		Chart5.LeftAxis.Range.UseMin := true;
		Chart5.LeftAxis.Range.UseMax := true;
		axis := Chart5.AxisList[2];
		axis.visible := false;
		axis := Chart5.AxisList[3];
		labels := cLabelsXSpan (first, last);
		src := TListChartSource.Create (Chart5);
		for i := 0 to high (labels) do
			src.add (labels[i], labels[i]);
		axis.Marks.Source := src;
		axis.Title.caption := labelX;
		axis.Title.visible := true;
		axis.visible := true;
		Chart5.BottomAxis.visible := false;
		setLength (labels, 0);
	end;

	procedure TGraphsForm.ChildGroomChange(Sender: TObject);
	begin
		Chart5.ClearSeries;
		case ChildGroomList.ItemIndex of
		kItemSearchBoth:
			drawSearchBoth;
		kItemMotherByGeneration:
			drawSearchByGeneration (gMotherSearch, gMotherSearchMiss, 'Mother search',
					gFirstCohortAncestorsChildren, gLastCohortAncestorsChildren,
					gChildStateMarginBelow, gChildStateMarginAbove);
		kItemBrideByGeneration:
			drawSearchByGeneration (gBrideSearch, gBrideSearchMiss, 'Bride search',
					gFirstCohortGrooms, gLastCohortGrooms,
					gGroomStateMarginBelow, gGroomStateMarginAbove);
		kItemUnionsOffered:
			drawUnionsByGroomCohort;
		end;
	end;
// <<< Claude 2026-09-12 end

	procedure TGraphsForm.ChildGroomEnter(Sender: TObject);
	begin
		OKChildGroom.Default := True;
	end;

	procedure TGraphsForm.ChildGroomClose(Sender: TObject);
	begin
		OKChildGroom.Default := False;
	end;

	procedure TGraphsForm.SaveChartSeriesToFile(ASeriesList: TChartSeriesList; aTitle: String = '');
	begin
		SaveDialog.Title := 'Write a data file';
		SaveDialog.Filter := 'Data file|*.txt';
		SaveDialog.DefaultExt := 'txt';
		if checkDirResult () then
			SaveDialog.InitialDir:= gPathToResult;
		if aTitle <> '' then
			SaveDialog.FileName := aTitle + '.TXT'
		else
			SaveDialog.FileName := 'DATA.TXT';
		SaveDialog.Options := SaveDialog.Options + [ofOverwritePrompt];
		if SaveDialog.Execute then
		begin
			SaveToFile (ASeriesList, SaveDialog.Filename);
		end;
	end;

	procedure TGraphsForm.SaveToFileFixedInputsClick(Sender: TObject);
	begin
		SaveChartSeriesToFile (Chart1.Series, InputsList.Items [InputsList.ItemIndex]);
	end;

	procedure TGraphsForm.SaveToFileVariableInputsClick(Sender: TObject);
	begin
		SaveChartSeriesToFile (Chart2.Series, InputsVarList.Items [InputsVarList.ItemIndex]);
	end;

	procedure TGraphsForm.SaveToFileOutputsFertilityClick(Sender: TObject);
	begin
		SaveChartSeriesToFile (Chart3.Series, OutputsList.Items [OutputsList.ItemIndex]);
	end;

	procedure TGraphsForm.SaveToFileOutputsKinshipClick(Sender: TObject);
	begin
		SaveChartSeriesToFile (Chart4.Series, OutputsKinshipList.Items [OutputsKinshipList.ItemIndex]);
	end;

	procedure TGraphsForm.SaveToFileChildGroomInfoClick(Sender: TObject);
	begin
		SaveChartSeriesToFile (Chart5.Series, ChildGroomList.Items [ChildGroomList.ItemIndex]);
	end;

end.


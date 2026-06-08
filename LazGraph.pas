unit LazGraph;

{$mode objfpc}{$H+}

interface

uses
	{$IFDEF UNIX}
	cthreads,
	{$ENDIF}
	Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, ComCtrls, ExtCtrls, StdCtrls,
	Declarations, DemographicRegime, Kinship, Utilities, StringOfLib, Math,
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

	// clRed, clLime, clBlue, clFuchsia, clAqua, clYellow, clMaroon, clGreen, clOlive, clNavy
		prop_colors := arrayOfLongint.Create(
			clRed, clLime, clBlue, clFuchsia, clAqua, clYellow, clMaroon, clGreen, clOlive, clNavy,
			clRed, clLime, clBlue, clFuchsia, clAqua, clYellow, clMaroon, clGreen, clOlive, clNavy,
			clRed, clLime, clBlue, clFuchsia, clAqua, clYellow, clMaroon, clGreen, clOlive, clNavy,
			clRed, clLime, clBlue, clFuchsia, clAqua, clYellow, clMaroon, clGreen, clOlive, clNavy
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
			Items.Add('schedule temporary sterility');
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
	begin
		Chart1.ClearSeries;
		case InputsList.ItemIndex of	//what entry (which item) has currently been chosen
			0: Draw(Chart1, 1, gFecundability,
				TDrawParameters.Create('Age in years', 'Monthly (lunar) probability', kNoSeriesTitle,
											'Fecundability: monthly (lunar) probability of pregnancy start'));
			1: Draw(Chart1, 1, gSchedule_temporary_sterility,
				'Duration in lunar months after previous childbirth',
				'Probability of amenorrhea', kNoSeriesTitle,
				'Lesthaeghe-Page standard schedule of amenorrhea');
			2: begin
				dp := TDrawParameters.Create('Age in years', 'Probability of being sterile',
				kNoSeriesTitle, 'Permanent Sterility by age', kNoLegendTitle,
				kLastValueIsNotTotal, kNoScaleFactor);
				setLength(range{%H-}, 1);
				range [0] := 11;
				dp.rangeValuesX := range;
				Draw(Chart1, 1, gDefinitive_sterility, dp);
				setLength(range, 0);
			end;
			3: Draw(Chart1, 1, gDistrib_fecundability, 'Intervals between 0 and 1',
							'Proportion of women with relative level under interval', kNoSeriesTitle,
							'Distribution of fecundability across women (around mean level of: ' + floatToStr (gMean_fecundability) + ')');
			4: begin
				dp := TDrawParameters.Create('Fecundability probability', 'Proportion of women',
															kNoSeriesTitle, 'Highest fecundability value (at age 22)', kNoLegendTitle,
															kLastValueIsNotTotal, kNoScaleFactor);
				dp.scaleFactorX := 1 / kMaxDistribFecundability;
				setLength (temp{%H-}, kMaxDistribFecundability+1);
				for i := 1 to kMaxDistribFecundability do begin
					temp[i] := gDistrib_fecundability[i] - gDistrib_fecundability[i-1];
				end;
				Draw(Chart1, 1, temp, dp);
				setLength (temp, 0);
			end;
			5: begin
				dp := TDrawParameters.Create('Age in years', 'Probability',
													kNoSeriesTitle, 'Intrauterine Mortality Risk: probability of having a natural abortion if pregnant', kNoLegendTitle,
													kLastValueIsNotTotal, kNoScaleFactor);
				setLength(range, 2);
				range [0] := 11;
				range [1] := 58;
				dp.rangeValuesX := range;
				Draw(Chart1, 1, gIntrauterine_mortality_risk, dp);
				setLength(range, 0);
			end;
			6: Draw(Chart1, 1, gDistrib_intrauterine_mortality_risk,
				TDrawParameters.Create('Lunar month of pregnancy terminated by a natural abortion',
											'Proportion of pregnancies with natural abortion', kNoSeriesTitle, 'Distribution of intrauterine mortality risk across pregnancies', kNoLegendTitle,
											kLastValueIsNotTotal, kNoScaleFactor, kNoOffsetX, [0, 1, 2, 3, 4, 5, 6, 7, 8], []));
			7: begin
				dp := TDrawParameters.Create('Age in years', 'Probability of a stillbirth',
													kNoSeriesTitle, 'Stillbirth risk by age', kNoLegendTitle,
													kLastValueIsNotTotal, kNoScaleFactor);
				setLength(range, 2);
				range [0] := 11;
				range [1] := 58;
				dp.rangeValuesX := range;
				Draw(Chart1, 1, gStillbirth_mortality_risk, dp);
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
			4:	Draw(Chart2, 1, prop_pDemReg^.temporary_sterility,
						'Lunar months after end of pregnancy',
						'Probability of being temporary sterile (amenorrhea post partum)', kNoSeriesTitle);
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

	procedure TGraphsForm.ChildGroomCreate;
	begin
		with ChildGroomList do begin
			Items.Clear;
			Items.Add('state Grooms');
			Items.Add('state Children');
			//Items.Add('state Brides');
			//Items.Add('state Mothers');
			//Items.Add('state Years');
			ItemIndex := 0;
		end;
		ChildGroomChange(self);
	end;

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

	procedure TGraphsForm.ChildGroomChange(Sender: TObject);
	var
		dp: TDrawParameters;
	begin
		Chart5.ClearSeries;
		dp := TDrawParameters.Create('Cohort', 'Count');
		case ChildGroomList.ItemIndex of	//what entry (which item) has currently been chosen
		0:
			begin
				dp.chartTitle := 'Count of grooms';
				dp.offsetLabelX:= gFirstCohortGrooms - kStateRangeLengthLimit;
				dp.labelsX := clabelsX(gFirstCohortGrooms, gLastCohortGrooms);
				DrawIntegers(Chart5, 1, gStateGrooms, dp);
			end;
		1:
			begin
				dp.chartTitle := 'Count of children';
				dp.offsetLabelX := gFirstCohortAncestorsChildren - kStateRangeLengthLimit;
				dp.labelsX := clabelsX(gFirstCohortAncestorsChildren, gLastCohortAncestorsChildren);
				DrawIntegers(Chart5, 1, gStateChildren, dp);
			end;
		2:
			begin
				dp.chartTitle := 'Count of brides';
				dp.offsetLabelX := gFirstCohortBrides - kStateRangeLengthLimit;
				dp.labelsX := clabelsX(gFirstCohortBrides, gLastCohortBrides);
				DrawIntegers(Chart5, 1, gStateBrides, dp);
			end;
		3:
			begin
				dp.chartTitle := 'Count of mothers';
				dp.offsetLabelX := gFirstCohortWomen - kStateRangeLengthLimit;
				dp.labelsX := clabelsX(gFirstCohortWomen, gLastCohortWomen);
				DrawIntegers(Chart5, 1, gStateMothers, dp);
			end;
		4:
			begin
				dp.chartTitle := 'Count of union years';
				dp.offsetLabelX := gFirstYearUnions - kStateRangeLengthLimit;
				dp.labelsX := clabelsX(gFirstYearUnions, gLastYearUnions);
				DrawIntegers(Chart5, 1, gStateYearUnions, dp);
			end;
		end;
	end;

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


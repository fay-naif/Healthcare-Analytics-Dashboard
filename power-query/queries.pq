// Power Query (M) — Healthcare Analytics Dashboard
// Data preparation by Fay Naif.
// The long embedded copy of the dataset is shortened to <embedded copy of the data>; the full query is in the .SemanticModel folder.

// ===== Table: Visits =====
let
    // 1) Try the Excel workbook at the FilePath parameter (6 sheets, joined here into one visit-level table).
    // 2) If it is not there, use the copy of the same joined data embedded below.
    FromFile = try Table.Buffer(
        let
            Wb = Excel.Workbook(File.Contents(FilePath), null, true),
            V = Wb{[Item="Visits",Kind="Sheet"]}[Data],
            B = Wb{[Item="Billing",Kind="Sheet"]}[Data],
            Pt = Wb{[Item="Patients",Kind="Sheet"]}[Data],
            Sv = Wb{[Item="Services",Kind="Sheet"]}[Data],
            Fc = Wb{[Item="Facilities",Kind="Sheet"]}[Data],
            J1 = Table.ExpandTableColumn(Table.NestedJoin(V, {"Visit_ID"}, B, {"Visit_ID"}, "B", JoinKind.LeftOuter), "B", {"Charge_SAR", "Collected_SAR"}),
            J2 = Table.ExpandTableColumn(Table.NestedJoin(J1, {"Patient_ID"}, Pt, {"Patient_ID"}, "P", JoinKind.LeftOuter), "P", {"Gender", "Age", "City", "Payment_Type"}, {"Gender", "Age", "Patient_City", "Payment_Type"}),
            J3 = Table.ExpandTableColumn(Table.NestedJoin(J2, {"Service_ID"}, Sv, {"Service_ID"}, "S", JoinKind.LeftOuter), "S", {"Service_Name"}),
            J4 = Table.ExpandTableColumn(Table.NestedJoin(J3, {"Facility_ID"}, Fc, {"Facility_ID"}, "F", JoinKind.LeftOuter), "F", {"Facility_Name", "City", "Beds"}, {"Facility_Name", "Facility_City", "Beds"})
        in
            J4
    ) otherwise null,
    Embedded = Table.PromoteHeaders(Csv.Document(Binary.Decompress( Binary.FromText("<embedded copy of the data>", BinaryEncoding.Base64), Compression.Deflate), [Delimiter=",", Encoding=65001, QuoteStyle=QuoteStyle.Csv]), [PromoteAllScalars=true]),
    Source = if FromFile <> null then FromFile else Embedded,
    Selected = Table.SelectColumns(Source, {"Visit_ID", "Visit_Date", "Patient_ID", "Gender", "Age", "Patient_City", "Payment_Type", "Facility_Name", "Facility_City", "Beds", "Department", "Provider_ID", "Diagnosis", "Service_Name", "Wait_Minutes", "Outcome", "Charge_SAR", "Collected_SAR"}),
    Typed = Table.TransformColumnTypes(Selected, {{"Visit_ID", type text}, {"Visit_Date", type date}, {"Patient_ID", type text}, {"Gender", type text}, {"Age", Int64.Type}, {"Patient_City", type text}, {"Payment_Type", type text}, {"Facility_Name", type text}, {"Facility_City", type text}, {"Beds", Int64.Type}, {"Department", type text}, {"Provider_ID", type text}, {"Diagnosis", type text}, {"Service_Name", type text}, {"Wait_Minutes", Int64.Type}, {"Outcome", type text}, {"Charge_SAR", type number}, {"Collected_SAR", type number}}, "en-US"),
    AddYear = Table.AddColumn(Typed, "Year", each Date.Year([Visit_Date]), Int64.Type),
    AddUncollected = Table.AddColumn(AddYear, "Uncollected_SAR", each [Charge_SAR] - [Collected_SAR], type number),
    AddWaitBand = Table.AddColumn(AddUncollected, "Wait_Band", each if [Wait_Minutes] <= 30 then "0-30 min" else if [Wait_Minutes] <= 60 then "31-60 min" else if [Wait_Minutes] <= 90 then "61-90 min" else if [Wait_Minutes] <= 120 then "91-120 min" else "121-150 min", type text),
    AddWaitOrder = Table.AddColumn(AddWaitBand, "Wait_Band_Order", each if [Wait_Minutes] <= 30 then 1 else if [Wait_Minutes] <= 60 then 2 else if [Wait_Minutes] <= 90 then 3 else if [Wait_Minutes] <= 120 then 4 else 5, Int64.Type),
    AddAgeGroup = Table.AddColumn(AddWaitOrder, "Age_Group", each if [Age] <= 17 then "0-17" else if [Age] <= 34 then "18-34" else if [Age] <= 49 then "35-49" else if [Age] <= 64 then "50-64" else "65+", type text),
    AddAgeOrder = Table.AddColumn(AddAgeGroup, "Age_Group_Order", each if [Age] <= 17 then 1 else if [Age] <= 34 then 2 else if [Age] <= 49 then 3 else if [Age] <= 64 then 4 else 5, Int64.Type)
in
    AddAgeOrder

// ===== Calculated table (DAX): Date =====
Date =
ADDCOLUMNS(CALENDAR(DATE(YEAR(MIN(Visits[Visit_Date])), 1, 1), DATE(YEAR(MAX(Visits[Visit_Date])), 12, 31)), "Year", YEAR([Date]), "Quarter", "Q" & QUARTER([Date]), "Month Num", MONTH([Date]), "Month", FORMAT([Date], "MMM"), "Year Month", FORMAT([Date], "MMM yyyy"), "YearMonthNum", YEAR([Date]) * 100 + MONTH([Date]))

// ===== Parameter: FilePath =====
FilePath = "C:\Users\Public\Healthcare_Analytics_Clean_30000.xlsx" meta [IsParameterQuery=true, Type="Text", IsParameterQueryRequired=true]

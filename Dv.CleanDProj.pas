unit Dv.CleanDProj;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.Generics.Defaults,
  System.Variants,
  XML.XMLIntf,
  XML.XMLDoc;

procedure DoCleanDproj(AStream: TStream);

implementation

function FindFirstNode(AParent: IXMLNode; ANodes: TArray<string>): IXMLNode;
var
  I: Integer;
begin
  Result := AParent;
  for I := 0 to High(ANodes) do
  begin
    Result := Result.ChildNodes.FindNode(ANodes[I]);
    if Result = nil then
      Break;
  end;
  if I <> Length(ANodes) then
    Result := nil;
end;

function NodeListToArray(ANodes: IXMLNodeList): TArray<IXMLNode>;
var
  I: Integer;
begin
  SetLength(Result, ANodes.Count);
  for I := 0 to ANodes.Count - 1 do
    Result[I] := ANodes.Get(I);
end;

function ForceVarToStr(AValue: Variant): string;
begin
  if AValue = Null then
    Result := ''
  else
    Result := AValue;
end;

function CompareXMLNode(const Left, Right: IXMLNode): Integer;
var
  ALeftAttrs, ARightAttrs: TArray<IXMLNode>;
  I: Integer;
begin
  if Left = Right then
    Exit(0);
  // Compare tag
  Result := CompareStr(Left.Prefix + Left.NodeName, Right.Prefix + Right.NodeName);
  // Compare attributes
  if Result = 0 then
  begin
    ALeftAttrs := NodeListToArray(Left.AttributeNodes);
    ARightAttrs := NodeListToArray(Right.AttributeNodes);
    for I := Low(ALeftAttrs) to High(ALeftAttrs) do
    begin
      if I > High(ARightAttrs) then
        Result := 1;
      if Result <> 0 then
        Break;
      Result := CompareStr(ALeftAttrs[I].NodeName, ARightAttrs[I].NodeName);
      if Result <> 0 then
        Break;
      Result := CompareText(ForceVarToStr(ALeftAttrs[I].NodeValue), ForceVarToStr(ARightAttrs[I].NodeValue));
      if Result <> 0 then
        Break;
    end;
    if (Result = 0) and (High(ALeftAttrs) > High(ARightAttrs)) then
      Result := -1;
  end;
  // Compare full XML
  if Result = 0 then
    Result := CompareStr(Left.XML, Right.XML);
  // Compare index in parent
  if (Result = 0) and (Left.ParentNode <> nil) and (Right.ParentNode <> nil) then
    Result := Left.ParentNode.ChildNodes.IndexOf(Left) - Right.ParentNode.ChildNodes.IndexOf(Right);
end;

procedure SortNodes(ANodes: IXMLNodeList);
var
  ANodeArray: TArray<IXMLNode>;
  I: Integer;
begin
  SetLength(ANodeArray, ANodes.Count);
  for I := 0 to ANodes.Count - 1 do
    ANodeArray[I] := ANodes.Nodes[I];
  TArray.Sort<IXMLNode>(ANodeArray, TComparer<IXMLNode>.Construct(CompareXMLNode));
  ANodes.Clear;
  for I := 0 to Length(ANodeArray) - 1 do
    ANodes.Add(ANodeArray[I]);
end;

procedure DoCleanDproj(AStream: TStream);
var
  ADocument: IXMLDocument;
  AByteOrderMark: TBytes; // BOM
  ANode: IXMLNode;
  AStreamReader: TStreamReader;
  AStreamWriter: TStreamWriter;
  AText: string;
begin
  ADocument := NewXMLDocument;
  // Import
  ADocument.NodeIndentStr := '    ';
  ADocument.Options := ADocument.Options + [doNodeAutoIndent];
  //ADocument.ParseOptions := [poValidateOnParse, poPreserveWhiteSpace];
  ADocument.LoadFromStream(AStream, xetUTF_8);
  // Sort the shit
  ANode := FindFirstNode(ADocument.Node, ['Project', 'ProjectExtensions', 'BorlandProject', 'Deployment']);
  if ANode <> nil then
    SortNodes(ANode.ChildNodes);
  ANode := FindFirstNode(ADocument.Node, ['Project', 'ItemGroup']);
  if ANode <> nil then
    SortNodes(ANode.ChildNodes);
  // Reset file
  AStream.Position := 0;
  AStream.Size := 0;
  // Reset build config
  ANode := FindFirstNode(ADocument.Node, ['Project', 'PropertyGroup', 'Config']);
  if ANode <> nil then
    ANode.Text := 'Release';
  // Save the xml
  ADocument.SaveToStream(AStream);
  // Replace tabs for spaces
  AStreamReader := TStreamReader.Create(AStream, True);
  try
    AStream.Position := 0;
    AText := AStreamReader.ReadToEnd;
  finally
    AStreamReader.Free;
  end;
  AStreamWriter := TStreamWriter.Create(AStream, TEncoding.UTF8);
  try
    // Reset file
    AStream.Position := 0;
    AStream.Size := 0;
    // Write an encoding byte-order mark and buffer to output file.
    AByteOrderMark := TUTF8Encoding.UTF8.GetPreamble;
    AStream.Write(AByteOrderMark[0], Length(AByteOrderMark));
    // Remove lines
    AText := AText.Replace(#9, '    ');
    AStreamWriter.Write(AText);
  finally
    AStreamWriter.Free;
  end;
end;

end.

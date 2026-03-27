// Deploy model to local Power BI instance via Tabular Editor script
// Usage: TabularEditor.exe model.bim -S deploy_model.cs

// Save back to connected instance
Model.Database.Update(Microsoft.AnalysisServices.UpdateOptions.ExpandFull);
Output("Model deployed successfully. Tables: " + Model.Tables.Count.ToString());

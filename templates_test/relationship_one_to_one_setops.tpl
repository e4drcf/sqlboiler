{{- define "relationship_to_one_setops_test_helper" -}}
{{- $dot := .Dot -}}
{{- with .Rel -}}
{{- $varNameSingular := .ForeignKey.Table | singular | camelCase -}}
{{- $foreignVarNameSingular := .ForeignKey.ForeignTable | singular | camelCase}}
func test{{.LocalTable.NameGo}}ToOneSetOp{{.ForeignTable.NameGo}}_{{.Function.Name}}(t *testing.T) {
	var err error

	tx := MustTx(boil.Begin())
	defer tx.Rollback()

	var a {{.LocalTable.NameGo}}
	var b {{.ForeignTable.NameGo}}
	{{if not .Function.OneToOne -}}
	var c {{.ForeignTable.NameGo}}
	{{- end}}

	seed := randomize.NewSeed()
	if err = randomize.Struct(seed, &a, {{$varNameSingular}}DBTypes, false, strmangle.SetComplement({{$varNameSingular}}PrimaryKeyColumns, {{$varNameSingular}}ColumnsWithoutDefault)...); err != nil {
		t.Fatal(err)
	}
	if err = randomize.Struct(seed, &b, {{$foreignVarNameSingular}}DBTypes, false, strmangle.SetComplement({{$foreignVarNameSingular}}PrimaryKeyColumns, {{$foreignVarNameSingular}}ColumnsWithoutDefault)...); err != nil {
		t.Fatal(err)
	}
	{{if not .Function.OneToOne -}}
	if err = randomize.Struct(seed, &c, {{$foreignVarNameSingular}}DBTypes, false, strmangle.SetComplement({{$foreignVarNameSingular}}PrimaryKeyColumns, {{$foreignVarNameSingular}}ColumnsWithoutDefault)...); err != nil {
		t.Fatal(err)
	}
	{{- end}}

	if err := a.Insert(tx); err != nil {
		t.Fatal(err)
	}
	if err = b.Insert(tx); err != nil {
		t.Fatal(err)
	}

	for i, x := range []*{{.ForeignTable.NameGo}}{&b{{if not .Function.OneToOne}}, &c{{end}}} {
		err = a.Set{{.Function.Name}}(tx, i != 0, x)
		if err != nil {
			t.Fatal(err)
		}

		{{if .Function.UsesBytes -}}
		if 0 != bytes.Compare(a.{{.Function.LocalAssignment}}, x.{{.Function.ForeignAssignment}}) {
		{{else -}}
		if a.{{.Function.LocalAssignment}} != x.{{.Function.ForeignAssignment}} {
		{{end -}}
			t.Error("foreign key was wrong value", a.{{.Function.LocalAssignment}})
		}
		if a.R.{{.Function.Name}} != x {
			t.Error("relationship struct not set to correct value")
		}

		{{if .Function.OneToOne -}}
		zero := reflect.Zero(reflect.TypeOf(x.{{.Function.ForeignAssignment}}))
		reflect.Indirect(reflect.ValueOf(&x.{{.Function.ForeignAssignment}})).Set(zero)

		xrel := x.R
		if err = x.Reload(tx); err != nil {
			t.Fatal("failed to reload", err)
		}
		x.R = xrel
		{{else -}}
		zero := reflect.Zero(reflect.TypeOf(a.{{.Function.LocalAssignment}}))
		reflect.Indirect(reflect.ValueOf(&a.{{.Function.LocalAssignment}})).Set(zero)

		if err = a.Reload(tx); err != nil {
			t.Fatal("failed to reload", err)
		}
		{{- end}}

		{{if .Function.UsesBytes -}}
		if 0 != bytes.Compare(a.{{.Function.LocalAssignment}}, x.{{.Function.ForeignAssignment}}) {
		{{else -}}
		if a.{{.Function.LocalAssignment}} != x.{{.Function.ForeignAssignment}} {
		{{end -}}
			t.Error("foreign key was wrong value", a.{{.Function.LocalAssignment}}, x.{{.Function.ForeignAssignment}})
		}

		{{if .ForeignKey.Unique -}}
		if x.R.{{.Function.ForeignName}} != &a {
			t.Error("failed to append to foreign relationship struct")
		}
		{{else -}}
		if x.R.{{.Function.ForeignName}}[0] != &a {
			t.Error("failed to append to foreign relationship struct")
		}
		{{end -}}
	}
}
{{- if or (.ForeignKey.Nullable) (and .Function.OneToOne .ForeignKey.ForeignColumnNullable)}}

func test{{.LocalTable.NameGo}}ToOneRemoveOp{{.ForeignTable.NameGo}}_{{.Function.Name}}(t *testing.T) {
	var err error

	tx := MustTx(boil.Begin())
	defer tx.Rollback()

	var a {{.LocalTable.NameGo}}
	var b {{.ForeignTable.NameGo}}

	seed := randomize.NewSeed()
	if err = randomize.Struct(seed, &a, {{$varNameSingular}}DBTypes, false, strmangle.SetComplement({{$varNameSingular}}PrimaryKeyColumns, {{$varNameSingular}}ColumnsWithoutDefault)...); err != nil {
		t.Fatal(err)
	}
	if err = randomize.Struct(seed, &b, {{$foreignVarNameSingular}}DBTypes, false, strmangle.SetComplement({{$foreignVarNameSingular}}PrimaryKeyColumns, {{$foreignVarNameSingular}}ColumnsWithoutDefault)...); err != nil {
		t.Fatal(err)
	}

	if err = a.Insert(tx); err != nil {
		t.Fatal(err)
	}

	if err = a.Set{{.Function.Name}}(tx, true, &b); err != nil {
		t.Fatal(err)
	}

	if err = a.Remove{{.Function.Name}}(tx, &b); err != nil {
		t.Error("failed to remove relationship")
	}

	count, err := a.{{.Function.Name}}(tx).Count()
	if err != nil {
		t.Error(err)
	}
	if count != 0 {
		t.Error("want no relationships remaining")
	}

	if a.R.{{.Function.Name}} != nil {
		t.Error("R struct entry should be nil")
	}

	{{if .Function.OneToOne -}}
	if b.{{.ForeignTable.ColumnNameGo}}.Valid {
		t.Error("R struct entry should be nil")
	}
	{{else -}}
	if a.{{.LocalTable.ColumnNameGo}}.Valid {
		t.Error("R struct entry should be nil")
	}
	{{- end}}

	{{if .ForeignKey.Unique -}}
	if b.R.{{.Function.ForeignName}} != nil {
		t.Error("failed to remove a from b's relationships")
	}
	{{else -}}
	if len(b.R.{{.Function.ForeignName}}) != 0 {
		t.Error("failed to remove a from b's relationships")
	}
	{{- end}}
}
{{end -}}{{/* end if foreign key nullable */}}
{{- end -}}{{/* with rel */}}
{{- end -}}{{/* define */}}
{{- if .Table.IsJoinTable -}}
{{- else -}}
	{{- $dot := . -}}
	{{- range .Table.FKeys -}}
		{{- $txt := textsFromForeignKey $dot.PkgName $dot.Tables $dot.Table .}}
{{template "relationship_to_one_setops_test_helper" (preserveDot $dot $txt) -}}
{{- end -}}
{{- end -}}

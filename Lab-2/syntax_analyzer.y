%{
#include "symbol_table.h"
#include <bits/stdc++.h>
using namespace std;

#define YYSTYPE symbol_info*

int yyparse(void);
int yylex(void);

extern FILE *yyin;
extern YYSTYPE yylval;

ofstream outlog;
ofstream outerror;

symbol_table* main_table = nullptr;
int lines = 1;
int error_count = 0;

/*helpers*/
static inline bool isNumericType(const string& t){
    return (t == "int" || t == "float");
}
static inline bool isVoidType(const string& t){
    return (t == "void");
}
static inline bool isUndefinedType(const string& t){
    return (t.empty() || t == "undefined");
}
static inline string promoteNumeric(const string& a, const string& b){
    if(isUndefinedType(a) || isUndefinedType(b)) return "undefined";
    if(isVoidType(a) || isVoidType(b)) return "void";
    if(a == "float" || b == "float") return "float";
    return "int";
}

static inline symbol_info* lookup_by_name(const string& name){
    if(!main_table) return nullptr;
    symbol_info temp(name, "ID");
    return main_table->lookup(&temp);
}

/*removing spaces and strip outer parentheses repeatedly*/
static inline string stripSpaces(string s){
    s.erase(remove_if(s.begin(), s.end(), [](unsigned char c){ return isspace(c); }), s.end());
    return s;
}
static inline string stripParens(string s){
    s = stripSpaces(s);
    while(s.size() >= 2 && s.front()=='(' && s.back()==')'){
        s = s.substr(1, s.size()-2);
        s = stripSpaces(s);
    }
    return s;
}

static inline bool isZeroConstantExpr(symbol_info* e){
    if(!e) return false;
    string s = stripParens(e->get_name());
    if(s.empty()) return false;

    if(s[0]=='+' || s[0]=='-'){
        s = stripParens(s.substr(1));
    }
    if(s=="0") return true;
    if(s.size()>=2 && s[0]=='0' && s[1]=='.'){
        for(size_t i=2;i<s.size();i++){
            if(s[i] != '0') return false;
        }
        return true;
    }
    return false;
}

static inline string get_expression_type(symbol_info* e){
    if(!e) return "undefined";
    return e->get_data_type();
}

static inline bool isFunctionSymbol(symbol_info* s){
    if(!s) return false;
    string st = s->get_symbol_type();
    return (st == "Function Definition" || st == "Function Declaration");
}

/*Error output formatting*/
static inline void emit_error(int line, const string& msg){
    outerror << "At line no: " << line << " " << msg << "\n\n";
    error_count++;
}
static inline void emit_warning(int line, const string& msg){
    // sample warning still appears in same stream; and sample total counts it
    outerror << "At line no: " << line << " " << msg << "\n\n";
    error_count++;
}

static bool pending_func_params = false;
static vector<string> pending_param_types;
static vector<string> pending_param_names;
static string current_function_return_type = "";
static int current_function_scope_id = -1;
static string current_function_name = "";

static void inject_pending_params_into_scope(){
    if(!pending_func_params) return;
    current_function_scope_id = main_table->getCurrentScopeID();
    for(size_t i=0;i<pending_param_types.size();i++){
        string ptype = pending_param_types[i];
        string pname = (i < pending_param_names.size() ? pending_param_names[i] : "");

        if(pname.empty()) continue; // allows unnamed parameter but not inserted

        symbol_info* psym = new symbol_info(pname, "ID", "Variable");
        psym->set_data_type(ptype);

        if(!main_table->insert(psym)){
            // sample: Multiple declaration of variable a in parameter of foo2
            emit_error(lines, "Multiple declaration of variable " + pname + " in parameter of " + current_function_name);
        }
    }

    pending_func_params = false;
    pending_param_types.clear();
    pending_param_names.clear();
}

void yyerror(const char *s){
    emit_error(lines, string(s));
}
void yyerror(char *s){
    yyerror((const char*)s);
}

%}

%token IF ELSE FOR WHILE DO BREAK CONTINUE RETURN INT FLOAT CHAR DOUBLE VOID SWITCH CASE DEFAULT GOTO PRINTF ADDOP MULOP INCOP RELOP ASSIGNOP LOGICOP NOT LPAREN RPAREN LCURL RCURL LTHIRD RTHIRD COMMA SEMICOLON COLON ID CONST_INT CONST_FLOAT

%nonassoc LOWER_THAN_ELSE
%nonassoc ELSE

%%

start : program
{
    outlog << "At line no: " << lines << " start : program " << endl << endl;
    outlog << "Symbol Table" << endl << endl;
    main_table->print_all_scopes(outlog);
};

program : program unit
{
    outlog << "At line no: " << lines << " program : program unit " << endl << endl;
    outlog << $1->get_name() + "\n" + $2->get_name() << endl << endl;
    $$ = new symbol_info($1->get_name() + "\n" + $2->get_name(), "program");
}
| unit
{
    outlog << "At line no: " << lines << " program : unit " << endl << endl;
    outlog << $1->get_name() << endl << endl;
    $$ = new symbol_info($1->get_name(), "program");
};

unit : var_declaration
{
    outlog << "At line no: " << lines << " unit : var_declaration " << endl << endl;
    outlog << $1->get_name() << endl << endl;
    $$ = new symbol_info($1->get_name(), "unit");
}
| func_declaration
{
    outlog << "At line no: " << lines << " unit : func_declaration " << endl << endl;
    outlog << $1->get_name() << endl << endl;
    $$ = new symbol_info($1->get_name(), "unit");
}
| func_definition
{
    outlog << "At line no: " << lines << " unit : func_definition " << endl << endl;
    outlog << $1->get_name() << endl << endl;
    $$ = new symbol_info($1->get_name(), "unit");
};

func_declaration : type_specifier ID LPAREN parameter_list RPAREN SEMICOLON
{
    outlog << "At line no: " << lines << " func_declaration : type_specifier ID LPAREN parameter_list RPAREN SEMICOLON " << endl << endl;
    outlog << $1->get_name() << " " << $2->get_name() << "(" << $4->get_name() << ");" << endl << endl;
    $$ = new symbol_info($1->get_name() + " " + $2->get_name() + "(" + $4->get_name() + ");", "func_decl");

    string fname = $2->get_name();
    current_function_name = fname;
    symbol_info* existing = lookup_by_name(fname);

    if(existing){
        if(!isFunctionSymbol(existing)){
            emit_error(lines, "Multiple declaration of function " + fname);
        } else {
            if(existing->get_data_type() != $1->get_name() || existing->get_param_types() != $4->get_param_types()){
                emit_error(lines, "Multiple declaration of function " + fname);
            }
        }
    } else {
        symbol_info* fsym = new symbol_info(fname, "ID", "Function Declaration", $4->get_param_types(), $4->get_param_names());
        fsym->set_data_type($1->get_name());
        main_table->insert(fsym);
    }
}
| type_specifier ID LPAREN RPAREN SEMICOLON
{
    outlog << "At line no: " << lines << " func_declaration : type_specifier ID LPAREN RPAREN SEMICOLON " << endl << endl;
    outlog << $1->get_name() << " " << $2->get_name() << "();" << endl << endl;
    $$ = new symbol_info($1->get_name() + " " + $2->get_name() + "();", "func_decl");

    string fname = $2->get_name();
    current_function_name = fname;
    symbol_info* existing = lookup_by_name(fname);

    if(existing){
        if(!isFunctionSymbol(existing)){
            emit_error(lines, "Multiple declaration of function " + fname);
        } else {
            if(existing->get_data_type() != $1->get_name() || existing->get_param_types().size() != 0){
                emit_error(lines, "Multiple declaration of function " + fname);
            }
        }
    } else {
        symbol_info* fsym = new symbol_info(fname, "ID", "Function Declaration");
        fsym->set_data_type($1->get_name());
        main_table->insert(fsym);
    }
}
;

func_definition : type_specifier ID LPAREN parameter_list RPAREN
{
    current_function_return_type = $1->get_name();
    string fname = $2->get_name();
    current_function_name = fname;
    symbol_info* existing = lookup_by_name(fname);

    if(existing){
        if(existing->get_symbol_type() == "Function Definition" || existing->get_symbol_type() == "Function Declaration"){
            emit_error(lines, "Multiple declaration of function " + fname);
        } else {
            emit_error(lines, "Multiple declaration of function " + fname);
        }
    } else {
        symbol_info* fsym = new symbol_info(fname, "ID", "Function Definition", $4->get_param_types(), $4->get_param_names());
        fsym->set_data_type($1->get_name());
        if(!main_table->insert(fsym)){
            emit_error(lines, "Multiple declaration of function " + fname);
        }
    }

    pending_func_params = true;
    pending_param_types = $4->get_param_types();
    pending_param_names = $4->get_param_names();
}
compound_statement
{
    outlog << "At line no: " << lines << " func_definition : type_specifier ID LPAREN parameter_list RPAREN compound_statement " << endl << endl;

    outlog << $1->get_name() << " " << $2->get_name() << "(" << $4->get_name() << ")\n" << $7->get_name() << endl << endl;

    $$ = new symbol_info($1->get_name() + " " + $2->get_name() + "(" + $4->get_name() + ")\n" + $7->get_name(),"func_def");
}
| type_specifier ID LPAREN RPAREN
{
    current_function_return_type = $1->get_name();
    string fname = $2->get_name();
    current_function_name = fname;
    symbol_info* existing = lookup_by_name(fname);

    if(existing){
        emit_error(lines, "Multiple declaration of function " + fname);
    } else {
        symbol_info* fsym = new symbol_info(fname, "ID", "Function Definition");
        fsym->set_data_type($1->get_name());
        if(!main_table->insert(fsym)){
            emit_error(lines, "Multiple declaration of function " + fname);
        }
    }
    pending_func_params = true;
    pending_param_types.clear();
    pending_param_names.clear();
}
compound_statement
{
    outlog << "At line no: " << lines << " func_definition : type_specifier ID LPAREN RPAREN compound_statement " << endl << endl;
    outlog << $1->get_name() << " " << $2->get_name() << "()\n" << $6->get_name() << endl << endl;
    $$ = new symbol_info($1->get_name() + " " + $2->get_name() + "()\n" + $6->get_name(), "func_def");
};

parameter_list : parameter_list COMMA type_specifier ID
{
    outlog << "At line no: " << lines << " parameter_list : parameter_list COMMA type_specifier ID " << endl << endl;
    outlog << $1->get_name() << "," << $3->get_name() << " " << $4->get_name() << endl << endl;
    $$ = new symbol_info($1->get_name() + "," + $3->get_name() + " " + $4->get_name(), "param_list");

    vector<string> types = $1->get_param_types();
    vector<string> names = $1->get_param_names();
    types.push_back($3->get_name());
    names.push_back($4->get_name());
    $$->set_param_types(types);
    $$->set_param_names(names);
}
| parameter_list COMMA type_specifier
{
    outlog << "At line no: " << lines << " parameter_list : parameter_list COMMA type_specifier " << endl << endl;
    outlog << $1->get_name() << "," << $3->get_name() << endl << endl;
    $$ = new symbol_info($1->get_name() + "," + $3->get_name(), "param_list");

    vector<string> types = $1->get_param_types();
    vector<string> names = $1->get_param_names();
    types.push_back($3->get_name());
    names.push_back("");
    $$->set_param_types(types);
    $$->set_param_names(names);
}
| type_specifier ID
{
    outlog << "At line no: " << lines << " parameter_list : type_specifier ID " << endl << endl;
    outlog << $1->get_name() << " " << $2->get_name() << endl << endl;
    $$ = new symbol_info($1->get_name() + " " + $2->get_name(), "param_list");
    $$->set_param_types(vector<string>{ $1->get_name() });
    $$->set_param_names(vector<string>{ $2->get_name() });
}
| type_specifier
{
    outlog << "At line no: " << lines << " parameter_list : type_specifier " << endl << endl;
    outlog << $1->get_name() << endl << endl;
    $$ = new symbol_info($1->get_name(), "param_list");
    $$->set_param_types(vector<string>{ $1->get_name() });
    $$->set_param_names(vector<string>{ "" });
};

compound_statement : LCURL
{
    main_table->enter_scope();
    outlog << "New ScopeTable with ID " << main_table->getCurrentScopeID() << " created" << endl << endl;
    inject_pending_params_into_scope();
}
statements RCURL
{
    outlog << "At line no: " << lines << " compound_statement : LCURL statements RCURL " << endl << endl;
    outlog << "{\n" + $3->get_name() + "\n}" << endl << endl;
    $$ = new symbol_info("{\n" + $3->get_name() + "\n}", "comp_stmnt");

    main_table->print_all_scopes(outlog);
    int id = main_table->getCurrentScopeID();
    main_table->exit_scope();
    outlog << "Scopetable with ID " << id << " removed" << endl << endl;

    if(id == current_function_scope_id){
        current_function_scope_id = -1;
        current_function_return_type = "";
        current_function_name = "";
    }
}
| LCURL
{
    main_table->enter_scope();
    outlog << "New ScopeTable with ID " << main_table->getCurrentScopeID() << " created" << endl << endl;
    inject_pending_params_into_scope();
}
RCURL
{
    outlog << "At line no: " << lines << " compound_statement : LCURL RCURL " << endl << endl;
    outlog << "{\n}" << endl << endl;
    $$ = new symbol_info("{\n}", "compound_stmnt");

    main_table->print_all_scopes(outlog);
    int id = main_table->getCurrentScopeID();
    main_table->exit_scope();
    outlog << "Scopetable with ID " << id << " removed" << endl << endl;

    if(id == current_function_scope_id){
        current_function_scope_id = -1;
        current_function_return_type = "";
        current_function_name = "";
    }
};

var_declaration : type_specifier declaration_list SEMICOLON
{
    outlog << "At line no: " << lines << " var_declaration : type_specifier declaration_list SEMICOLON " << endl << endl;
    outlog << $1->get_name() << " " << $2->get_name() << ";" << endl << endl;
    $$ = new symbol_info($1->get_name() + " " + $2->get_name() + ";", "var_dec");

    string data_type = $1->get_name();
    if(data_type == "void"){
        emit_error(lines, "variable type can not be void");
        data_type = "undefined";
    }

    vector<string> vars;
    {
        string s = $2->get_name();
        string token;
        stringstream ss(s);
        while(getline(ss, token, ',')) vars.push_back(stripSpaces(token));
    }

    for(const string& var : vars){
        if(var.empty()) continue;

        size_t openb = var.find('[');
        size_t closeb = var.find(']');

        if(openb != string::npos && closeb != string::npos && closeb > openb + 1){
            string array_name = var.substr(0, openb);
            string size_str = var.substr(openb + 1, closeb - openb - 1);

            int array_size = 0;
            try { array_size = stoi(size_str); } catch(...) { array_size = 0; }

            symbol_info* sym = new symbol_info(array_name, "ID", "Array");
            sym->set_array_size(array_size);
            sym->set_data_type(data_type);

            if(!main_table->insert(sym)){
                emit_error(lines, "Multiple declaration of variable " + array_name);
            }
        } else {
            symbol_info* sym = new symbol_info(var, "ID", "Variable");
            sym->set_data_type(data_type);

            if(!main_table->insert(sym)){
                emit_error(lines, "Multiple declaration of variable " + var);
            }
        }
    }
};

type_specifier : INT   { outlog << "At line no:" << lines << " type_specifier : INT " << endl << endl;   outlog << "int" << endl << endl;   $$ = new symbol_info("int","type"); }
| FLOAT { outlog << "At line no:" << lines << " type_specifier : FLOAT " << endl << endl; outlog << "float" << endl << endl; $$ = new symbol_info("float","type"); }
| VOID  { outlog << "At line no:" << lines << " type_specifier : VOID " << endl << endl;  outlog << "void" << endl << endl;  $$ = new symbol_info("void","type"); }
| CHAR  { outlog << "At line no:" << lines << " type_specifier : CHAR " << endl << endl;  outlog << "char" << endl << endl;  $$ = new symbol_info("char","type"); }
| DOUBLE{ outlog << "At line no:" << lines << " type_specifier : DOUBLE " << endl << endl;outlog << "double" << endl << endl;$$ = new symbol_info("double","type"); 
};

declaration_list : declaration_list COMMA ID
{
    outlog << "At line no: " << lines << " declaration_list : declaration_list COMMA ID " << endl << endl;
    outlog << $1->get_name() << "," << $3->get_name() << endl << endl;
    $$ = new symbol_info($1->get_name() + "," + $3->get_name(), "declaration_list");
}
| declaration_list COMMA ID LTHIRD CONST_INT RTHIRD
{
    outlog << "At line no: " << lines << " declaration_list : declaration_list COMMA ID LTHIRD CONST_INT RTHIRD " << endl << endl;
    outlog << $1->get_name() << "," << $3->get_name() << "[" << $5->get_name() << "]" << endl << endl;
    $$ = new symbol_info($1->get_name() + "," + $3->get_name() + "[" + $5->get_name() + "]", "declaration_list");
}
| ID
{
    outlog << "At line no: " << lines << " declaration_list : ID " << endl << endl;
    outlog << $1->get_name() << endl << endl;
    $$ = new symbol_info($1->get_name(), "declaration_list");
}
| ID LTHIRD CONST_INT RTHIRD
{
    outlog << "At line no: " << lines << " declaration_list : ID LTHIRD CONST_INT RTHIRD " << endl << endl;
    outlog << $1->get_name() << "[" << $3->get_name() << "]" << endl << endl;
    $$ = new symbol_info($1->get_name() + "[" + $3->get_name() + "]", "declaration_list");
};

statements : statement
{
    outlog << "At line no: " << lines << " statements : statement " << endl << endl;
    outlog << $1->get_name() << endl << endl;
    $$ = new symbol_info($1->get_name(), "stmnts");
}
| statements statement
{
    outlog << "At line no: " << lines << " statements : statements statement " << endl << endl;
    outlog << $1->get_name() << "\n" << $2->get_name() << endl << endl;
    $$ = new symbol_info($1->get_name() + "\n" + $2->get_name(), "stmnts");
};

statement : var_declaration
{
    outlog << "At line no: " << lines << " statement : var_declaration " << endl << endl;
    outlog << $1->get_name() << endl << endl;
    $$ = new symbol_info($1->get_name(), "stmnt");
}
| expression_statement
{
    outlog << "At line no: " << lines << " statement : expression_statement " << endl << endl;
    outlog << $1->get_name() << endl << endl;
    $$ = new symbol_info($1->get_name(), "stmnt");
}
| compound_statement
{
    outlog << "At line no: " << lines << " statement : compound_statement " << endl << endl;
    outlog << $1->get_name() << endl << endl;
    $$ = new symbol_info($1->get_name(), "stmnt");
}
| FOR LPAREN expression_statement expression_statement expression RPAREN statement
{
    outlog << "At line no: " << lines << " statement : FOR LPAREN expression_statement expression_statement expression RPAREN statement " << endl << endl;
    outlog << "for(" << $3->get_name() << $4->get_name() << $5->get_name() << ")\n" << $7->get_name() << endl << endl;
    $$ = new symbol_info("for(" + $3->get_name() + $4->get_name() + $5->get_name() + ")\n" + $7->get_name(), "stmnt");
}
| IF LPAREN expression RPAREN statement %prec LOWER_THAN_ELSE
{
    outlog << "At line no: " << lines << " statement : IF LPAREN expression RPAREN statement " << endl << endl;
    outlog << "if(" << $3->get_name() << ")\n" << $5->get_name() << endl << endl;
    $$ = new symbol_info("if(" + $3->get_name() + ")\n" + $5->get_name(), "stmnt");
    if(isVoidType(get_expression_type($3))){
        emit_error(lines, "operation on void type");
    }
}
| IF LPAREN expression RPAREN statement ELSE statement
{
    outlog << "At line no: " << lines << " statement : IF LPAREN expression RPAREN statement ELSE statement " << endl << endl;
    outlog << "if(" << $3->get_name() << ")\n" << $5->get_name() << "\nelse\n" << $7->get_name() << endl << endl;
    $$ = new symbol_info("if(" + $3->get_name() + ")\n" + $5->get_name() + "\nelse\n" + $7->get_name(), "stmnt");
    if(isVoidType(get_expression_type($3))){
        emit_error(lines, "operation on void type");
    }
}
| WHILE LPAREN expression RPAREN statement
{
    outlog << "At line no: " << lines << " statement : WHILE LPAREN expression RPAREN statement " << endl << endl;
    outlog << "while(" << $3->get_name() << ")\n" << $5->get_name() << endl << endl;
    $$ = new symbol_info("while(" + $3->get_name() + ")\n" + $5->get_name(), "stmnt");
    if(isVoidType(get_expression_type($3))){
        emit_error(lines, "operation on void type");
    }
}
| DO statement WHILE LPAREN expression RPAREN SEMICOLON
{
    outlog << "At line no: " << lines << " statement : DO statement WHILE LPAREN expression RPAREN SEMICOLON " << endl << endl;
    outlog << "do\n" << $2->get_name() << "\nwhile(" << $5->get_name() << ");" << endl << endl;
    $$ = new symbol_info("do\n" + $2->get_name() + "\nwhile(" + $5->get_name() + ");", "stmnt");
    if(isVoidType(get_expression_type($5))){
        emit_error(lines, "operation on void type");
    }
}
| SWITCH LPAREN expression RPAREN statement
{
    outlog << "At line no: " << lines << " statement : SWITCH LPAREN expression RPAREN statement " << endl << endl;
    outlog << "switch(" << $3->get_name() << ")\n" << $5->get_name() << endl << endl;
    $$ = new symbol_info("switch(" + $3->get_name() + ")\n" + $5->get_name(), "stmnt");
}
| CASE CONST_INT COLON statement
{
    outlog << "At line no: " << lines << " statement : CASE CONST_INT COLON statement " << endl << endl;
    outlog << "case " << $2->get_name() << ":\n" << $4->get_name() << endl << endl;
    $$ = new symbol_info("case " + $2->get_name() + ":\n" + $4->get_name(), "stmnt");
}
| DEFAULT COLON statement
{
    outlog << "At line no: " << lines << " statement : DEFAULT COLON statement " << endl << endl;
    outlog << "default:\n" << $3->get_name() << endl << endl;
    $$ = new symbol_info("default:\n" + $3->get_name(), "stmnt");
}
| BREAK SEMICOLON
{
    outlog << "At line no: " << lines << " statement : BREAK SEMICOLON " << endl << endl;
    outlog << "break;" << endl << endl;
    $$ = new symbol_info("break;", "stmnt");
}
| CONTINUE SEMICOLON
{
    outlog << "At line no: " << lines << " statement : CONTINUE SEMICOLON " << endl << endl;
    outlog << "continue;" << endl << endl;
    $$ = new symbol_info("continue;", "stmnt");
}
| GOTO ID SEMICOLON
{
    outlog << "At line no: " << lines << " statement : GOTO ID SEMICOLON " << endl << endl;
    outlog << "goto " << $2->get_name() << ";" << endl << endl;
    $$ = new symbol_info("goto " + $2->get_name() + ";", "stmnt");
}
| ID COLON statement
{
    outlog << "At line no: " << lines << " statement : ID COLON statement " << endl << endl;
    outlog << $1->get_name() << ":\n" << $3->get_name() << endl << endl;
    $$ = new symbol_info($1->get_name() + ":\n" + $3->get_name(), "stmnt");
}
| PRINTF LPAREN ID RPAREN SEMICOLON
{
    outlog << "At line no: " << lines << " statement : PRINTF LPAREN ID RPAREN SEMICOLON " << endl << endl;
    outlog << "printf(" << $3->get_name() << ");" << endl << endl;
    $$ = new symbol_info("printf(" + $3->get_name() + ");", "stmnt");
    symbol_info* s = lookup_by_name($3->get_name());
    if(!s){
        emit_error(lines, "Undeclared variable " + $3->get_name());
    }
}
| RETURN SEMICOLON
{
    outlog << "At line no: " << lines << " statement : RETURN SEMICOLON " << endl << endl;
    outlog << "return;" << endl << endl;
    $$ = new symbol_info("return;", "stmnt");
}
| RETURN expression SEMICOLON
{
    outlog << "At line no: " << lines << " statement : RETURN expression SEMICOLON " << endl << endl;
    outlog << "return " << $2->get_name() << ";" << endl << endl;
    $$ = new symbol_info("return " + $2->get_name() + ";", "stmnt");
}
| error SEMICOLON
{
    yyerrok;
    $$ = new symbol_info(";", "stmnt");
};

expression_statement : SEMICOLON
{
    outlog << "At line no: " << lines << " expression_statement : SEMICOLON " << endl << endl;
    outlog << ";" << endl << endl;
    $$ = new symbol_info(";", "expr_stmt");
}
| expression SEMICOLON
{
    outlog << "At line no: " << lines << " expression_statement : expression SEMICOLON " << endl << endl;
    outlog << $1->get_name() << ";" << endl << endl;
    $$ = new symbol_info($1->get_name() + ";", "expr_stmt");
    $$->set_data_type(get_expression_type($1));
}
| error SEMICOLON
{
    yyerrok;
    $$ = new symbol_info(";", "expr_stmt");
    $$->set_data_type("undefined");
};

variable : ID
{
    outlog << "At line no: " << lines << " variable : ID " << endl << endl;
    outlog << $1->get_name() << endl << endl;
    symbol_info* sym = lookup_by_name($1->get_name());

    if(!sym){
        emit_error(lines, "Undeclared variable " + $1->get_name());
        $$ = new symbol_info($1->get_name(), "var");
        $$->set_data_type("undefined");
    }
    else if(sym->get_symbol_type() == "Array"){
        emit_error(lines, "variable is of array type : " + $1->get_name());
        $$ = new symbol_info($1->get_name(), "var");
        $$->set_data_type(sym->get_data_type());
    }
    else if(isFunctionSymbol(sym)){
        emit_error(lines, "Undeclared variable " + $1->get_name());
        $$ = new symbol_info($1->get_name(), "var");
        $$->set_data_type("undefined");
    }
    else{
        $$ = new symbol_info($1->get_name(), "var");
        $$->set_data_type(sym->get_data_type());
    }
}
| ID LTHIRD expression RTHIRD
{
    outlog << "At line no: " << lines << " variable : ID LTHIRD expression RTHIRD " << endl << endl;
    outlog << $1->get_name() << "[" << $3->get_name() << "]" << endl << endl;
    symbol_info* sym = lookup_by_name($1->get_name());

    if(!sym){
        emit_error(lines, "Undeclared variable " + $1->get_name());
        $$ = new symbol_info($1->get_name() + "[" + $3->get_name() + "]", "var");
        $$->set_data_type("undefined");
    }
    else if(sym->get_symbol_type() != "Array"){
        // sample: variable is not of array type : b
        emit_error(lines, "variable is not of array type : " + $1->get_name());
        $$ = new symbol_info($1->get_name() + "[" + $3->get_name() + "]", "var");
        $$->set_data_type(sym->get_data_type());
    }
    else{
        string idx_t = get_expression_type($3);
        if(!isUndefinedType(idx_t) && idx_t != "int"){
            // sample: array index is not of integer type : c
            emit_error(lines, "array index is not of integer type : " + $1->get_name());
        }
        $$ = new symbol_info($1->get_name() + "[" + $3->get_name() + "]", "var");
        $$->set_data_type(sym->get_data_type());
    }
};

expression : logic_expression
{
    outlog << "At line no: " << lines << " expression : logic_expression " << endl << endl;
    outlog << $1->get_name() << endl << endl;
    $$ = new symbol_info($1->get_name(), "expr");
    $$->set_data_type(get_expression_type($1));
}
| variable ASSIGNOP logic_expression
{
    outlog << "At line no: " << lines << " expression : variable ASSIGNOP logic_expression " << endl << endl;
    outlog << $1->get_name() << "=" << $3->get_name() << endl << endl;
    $$ = new symbol_info($1->get_name() + "=" + $3->get_name(), "expr");

    string lhs = get_expression_type($1);
    string rhs = get_expression_type($3);

    if(isUndefinedType(lhs) || isUndefinedType(rhs)){
        $$->set_data_type("undefined");
    }
    else if(isVoidType(rhs)){
        emit_error(lines, "operation on void type");
        $$->set_data_type("undefined");
    }
    else if(lhs == "int" && rhs == "float"){
        emit_warning(lines, "Warning: Assignment of float value into variable of integer type");
        $$->set_data_type("int");
    }
    else if(lhs != rhs && !(lhs=="float" && rhs=="int")){
        emit_error(lines, "Type mismatch in assignment");
        $$->set_data_type(lhs);
    }
    else{
        $$->set_data_type(lhs);
    }
};

logic_expression : rel_expression
{
    outlog << "At line no: " << lines << " logic_expression : rel_expression " << endl << endl;
    outlog << $1->get_name() << endl << endl;
    $$ = new symbol_info($1->get_name(), "logic_expr");
    $$->set_data_type(get_expression_type($1));
}
| rel_expression LOGICOP rel_expression
{
    outlog << "At line no: " << lines << " logic_expression : rel_expression LOGICOP rel_expression " << endl << endl;
    outlog << $1->get_name() << $2->get_name() << $3->get_name() << endl << endl;
    $$ = new symbol_info($1->get_name() + $2->get_name() + $3->get_name(), "logic_expr");

    string t1 = get_expression_type($1);
    string t2 = get_expression_type($3);

    if(isVoidType(t1) || isVoidType(t2)){
        emit_error(lines, "operation on void type");
        $$->set_data_type("undefined");
    } else {
        $$->set_data_type("int");
    }
};

rel_expression : simple_expression
{
    outlog << "At line no: " << lines << " rel_expression : simple_expression " << endl << endl;
    outlog << $1->get_name() << endl << endl;
    $$ = new symbol_info($1->get_name(), "rel_expr");
    $$->set_data_type(get_expression_type($1));
}
| simple_expression RELOP simple_expression
{
    outlog << "At line no: " << lines << " rel_expression : simple_expression RELOP simple_expression " << endl << endl;
    outlog << $1->get_name() << $2->get_name() << $3->get_name() << endl << endl;
    $$ = new symbol_info($1->get_name() + $2->get_name() + $3->get_name(), "rel_expr");

    string t1 = get_expression_type($1);
    string t2 = get_expression_type($3);

    if(isVoidType(t1) || isVoidType(t2)){
        emit_error(lines, "operation on void type");
        $$->set_data_type("undefined");
    } else {
        $$->set_data_type("int");
    }
};

simple_expression : term
{
    outlog << "At line no: " << lines << " simple_expression : term " << endl << endl;
    outlog << $1->get_name() << endl << endl;
    $$ = new symbol_info($1->get_name(), "simp_expr");
    $$->set_data_type(get_expression_type($1));
}
| simple_expression ADDOP term
{
    outlog << "At line no: " << lines << " simple_expression : simple_expression ADDOP term " << endl << endl;
    outlog << $1->get_name() << $2->get_name() << $3->get_name() << endl << endl;
    $$ = new symbol_info($1->get_name() + $2->get_name() + $3->get_name(), "simp_expr");

    string t1 = get_expression_type($1);
    string t2 = get_expression_type($3);

    if(isUndefinedType(t1) || isUndefinedType(t2)){
        $$->set_data_type("undefined");
    }
    else if(isVoidType(t1) || isVoidType(t2)){
        emit_error(lines, "operation on void type");
        $$->set_data_type("undefined");
    }
    else if(!isNumericType(t1) || !isNumericType(t2)){
        emit_error(lines, "Non-numeric operand used in arithmetic operation");
        $$->set_data_type("undefined");
    }
    else{
        $$->set_data_type(promoteNumeric(t1, t2));
    }
};

term : unary_expression
{
    outlog << "At line no: " << lines << " term : unary_expression " << endl << endl;
    outlog << $1->get_name() << endl << endl;
    $$ = new symbol_info($1->get_name(), "term");
    $$->set_data_type(get_expression_type($1));
}
| term MULOP unary_expression
{
    outlog << "At line no: " << lines << " term : term MULOP unary_expression " << endl << endl;
    outlog << $1->get_name() << $2->get_name() << $3->get_name() << endl << endl;
    $$ = new symbol_info($1->get_name() + $2->get_name() + $3->get_name(), "term");

    string t1 = get_expression_type($1);
    string t2 = get_expression_type($3);
    string op = $2->get_name();

    if(isUndefinedType(t1) || isUndefinedType(t2)){
        $$->set_data_type("undefined");
    }
    else if(isVoidType(t1) || isVoidType(t2)){
        emit_error(lines, "operation on void type");
        $$->set_data_type("undefined");
    }
    else if(!isNumericType(t1) || !isNumericType(t2)){
        emit_error(lines, "Non-numeric operand used in arithmetic operation");
        $$->set_data_type("undefined");
    }
    else{
        if(op == "%"){
            if(t1 != "int" || t2 != "int"){
                emit_error(lines, "Modulus operator on non integer type");
                $$->set_data_type("undefined");
            } else {
                if(isZeroConstantExpr($3)){
                    emit_error(lines, "Modulus by 0");
                }
                $$->set_data_type("int");
            }
        }
        else if(op == "/"){
            if(isZeroConstantExpr($3)){
                emit_error(lines, "Division by 0");
            }
            $$->set_data_type(promoteNumeric(t1, t2));
        }
        else{
            $$->set_data_type(promoteNumeric(t1, t2));
        }
    }
};

unary_expression : ADDOP unary_expression
{
    outlog << "At line no: " << lines << " unary_expression : ADDOP unary_expression " << endl << endl;
    outlog << $1->get_name() << $2->get_name() << endl << endl;
    $$ = new symbol_info($1->get_name() + $2->get_name(), "un_expr");
    $$->set_data_type(get_expression_type($2));
}
| NOT unary_expression
{
    outlog << "At line no: " << lines << " unary_expression : NOT unary_expression " << endl << endl;
    outlog << "!" << $2->get_name() << endl << endl;
    $$ = new symbol_info("!" + $2->get_name(), "un_expr");

    if(isVoidType(get_expression_type($2))){
        emit_error(lines, "operation on void type");
        $$->set_data_type("undefined");
    } else {
        $$->set_data_type("int");
    }
}
| factor
{
    outlog << "At line no: " << lines << " unary_expression : factor " << endl << endl;
    outlog << $1->get_name() << endl << endl;
    $$ = new symbol_info($1->get_name(), "un_expr");
    $$->set_data_type(get_expression_type($1));
};

factor : variable
{
    outlog << "At line no: " << lines << " factor : variable " << endl << endl;
    outlog << $1->get_name() << endl << endl;
    $$ = new symbol_info($1->get_name(), "factor");
    $$->set_data_type(get_expression_type($1));
}
| ID LPAREN argument_list RPAREN
{
    outlog << "At line no: " << lines << " factor : ID LPAREN argument_list RPAREN " << endl << endl;
    outlog << $1->get_name() << "(" << $3->get_name() << ")" << endl << endl;
    $$ = new symbol_info($1->get_name() + "(" + $3->get_name() + ")", "factor");

    symbol_info* sym = lookup_by_name($1->get_name());
    if(!sym){
        emit_error(lines, "Undeclared function: " + $1->get_name());
        $$->set_data_type("undefined");
    }
    else if(!isFunctionSymbol(sym)){
        emit_error(lines, "Undeclared function: " + $1->get_name());
        $$->set_data_type("undefined");
    }
    else {
        vector<string> param_types = sym->get_param_types();
        vector<string> arg_types   = $3->get_param_types();

        if(param_types.size() != arg_types.size()){
            emit_error(lines, "Inconsistencies in number of arguments in function call: " + $1->get_name());
        } else {
            for(size_t i=0;i<param_types.size();i++){
                string p = param_types[i];
                string a = arg_types[i];
                if(isUndefinedType(a)) continue;
                if(p == a) continue;
                if(p == "float" && a == "int") continue;
                emit_error(lines, "argument " + to_string((int)i+1) + " type mismatch in function call: " + $1->get_name());
            }
        }
        $$->set_data_type(sym->get_data_type());
    }
}
| LPAREN expression RPAREN
{
    outlog << "At line no: " << lines << " factor : LPAREN expression RPAREN " << endl << endl;
    outlog << "(" << $2->get_name() << ")" << endl << endl;
    $$ = new symbol_info("(" + $2->get_name() + ")", "factor");
    $$->set_data_type(get_expression_type($2));
}
| CONST_INT
{
    outlog << "At line no: " << lines << " factor : CONST_INT " << endl << endl;
    outlog << $1->get_name() << endl << endl;
    $$ = new symbol_info($1->get_name(), "factor");
    $$->set_data_type("int");
}
| CONST_FLOAT
{
    outlog << "At line no: " << lines << " factor : CONST_FLOAT " << endl << endl;
    outlog << $1->get_name() << endl << endl;
    $$ = new symbol_info($1->get_name(), "factor");
    $$->set_data_type("float");
}
| variable INCOP
{
    outlog << "At line no: " << lines << " factor : variable INCOP " << endl << endl;
    outlog << $1->get_name() << "++" << endl << endl;
    $$ = new symbol_info($1->get_name() + "++", "factor");
    $$->set_data_type(get_expression_type($1));
}
| INCOP variable
{
    outlog << "At line no: " << lines << " factor : INCOP variable " << endl << endl;
    outlog << "++" << $2->get_name() << endl << endl;
    $$ = new symbol_info("++" + $2->get_name(), "factor");
    $$->set_data_type(get_expression_type($2));
};

argument_list : arguments
{
    outlog << "At line no: " << lines << " argument_list : arguments " << endl << endl;
    outlog << $1->get_name() << endl << endl;
    $$ = new symbol_info($1->get_name(), "arg_list");
    $$->set_param_types($1->get_param_types());
}
|
{
    outlog << "At line no: " << lines << " argument_list : " << endl << endl;
    $$ = new symbol_info("", "arg_list");
    $$->set_param_types(vector<string>());
}
;

arguments : arguments COMMA logic_expression
{
    outlog << "At line no: " << lines << " arguments : arguments COMMA logic_expression " << endl << endl;
    outlog << $1->get_name() << ", " << $3->get_name() << endl << endl;
    $$ = new symbol_info($1->get_name() + ", " + $3->get_name(), "args");

    vector<string> types = $1->get_param_types();
    types.push_back(get_expression_type($3));
    $$->set_param_types(types);
}
| logic_expression
{
    outlog << "At line no: " << lines << " arguments : logic_expression " << endl << endl;
    outlog << $1->get_name() << endl << endl;
    $$ = new symbol_info($1->get_name(), "args");
    $$->set_param_types(vector<string>{ get_expression_type($1) });
};

%%

int main(int argc, char *argv[])
{
    if(argc != 2){
        cout << "Please input file name" << endl;
        return 0;
    }

    yyin = fopen(argv[1], "r");

    outlog.open("21301242_log.txt", ios::trunc);
    outerror.open("21301242_error.txt", ios::trunc);

    if(yyin == NULL){
        cout << "Couldn't open file" << endl;
        return 0;
    }

    main_table = new symbol_table(10);
    outlog << "New ScopeTable with ID " << main_table->getCurrentScopeID() << " created" << endl << endl;

    yyparse();

    outlog << endl << "Total lines: " << lines << endl;
    outlog << "Total errors: " << error_count << endl;
    outerror << "Total errors: " << error_count << endl;

    outlog.close();
    outerror.close();
    fclose(yyin);
    return 0;
}
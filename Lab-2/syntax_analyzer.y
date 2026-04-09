%{


#include"symbol_table.h"
using namespace std;
#define YYSTYPE symbol_info*

int yyparse(void);
int yylex(void);

extern FILE *yyin;
extern YYSTYPE yylval;

ofstream outlog;

symbol_table* main_table;
int lines = 1;

vector<string> split(const string& str, char delim) {
    vector<string> tokens;
    stringstream ss(str);
    string token;
    while (getline(ss, token, delim)) {
        tokens.push_back(token);
    }
    return tokens;
}

string symbol_type;
string data_type;
int array_size;
vector<string> parameter_types, parameter_names;

void yyerror(const char *s)
{
    outlog << "At line " << lines << " " << s << std::endl << std::endl;
}
%}

%token IF ELSE FOR WHILE DO BREAK INT CHAR FLOAT DOUBLE VOID RETURN SWITCH CASE DEFAULT CONTINUE PRINTF ADDOP MULOP INCOP DECOP RELOP ASSIGNOP LOGICOP NOT LPAREN RPAREN LCURL RCURL LTHIRD RTHIRD COMMA SEMICOLON ID CONST_INT CONST_FLOAT
%nonassoc LOWER_THAN_ELSE
%nonassoc ELSE
%%

start : program
	{
		outlog<<"At line no: "<<lines<<" start : program "<<endl<<endl;
		outlog<<"Symbol Table"<<endl<<endl;
		
		main_table->print_all_scopes(outlog); // Print the whole symbol table
	}
	;

program : program unit
	{
		outlog<<"At line no: "<<lines<<" program : program unit "<<endl<<endl;
		outlog<<$1->get_name()+"\n"+$2->get_name()<<endl<<endl;
		
		$$ = new symbol_info($1->get_name()+"\n"+$2->get_name(),"program");
	}
	| unit
	{
		outlog<<"At line no: "<<lines<<" program : unit "<<endl<<endl;
		outlog<<$1->get_name()<<endl<<endl;
		$$ = new symbol_info($1->get_name(),"program");
	}
	;

unit : var_declaration
	{
		outlog<<"At line no: "<<lines<<" unit : var_declaration "<<endl<<endl;
		outlog<<$1->get_name()<<endl<<endl;
		$$ = new symbol_info($1->get_name(),"unit");

	}
	| func_definition
	{
		outlog<<"At line no: "<<lines<<" unit : func_definition "<<endl<<endl;
		outlog<<$1->get_name()<<endl<<endl;  
		$$ = new symbol_info($1->get_name(),"unit");

	};

func_definition : type_specifier ID LPAREN parameter_list RPAREN 
{
			symbol_info* new_symbol = new symbol_info($2->get_name(), $2->get_type(), "Function Definition", $4->get_param_types(), $4->get_param_names());
			new_symbol->set_data_type($1->get_name());
			main_table->insert(new_symbol);
			
			main_table->enter_scope();
			outlog << "New ScopeTable with ID " << main_table->getCurrentScopeID() << " created" << endl << endl;
			
			auto param_types = $4->get_param_types();
			auto param_names = $4->get_param_names();

			if (param_types.size() == param_names.size()) {
				for (size_t i = 0; i < param_types.size(); ++i) {
					symbol_info* param_symbol = new symbol_info(param_names[i], "ID", "Variable");
					param_symbol->set_data_type(param_types[i]);  // Set the correct type
					main_table->insert(param_symbol);
				}
			}
				
}

compound_statement
	{	
		outlog<<"At line no: "<<lines<<" func_definition : type_specifier ID LPAREN parameter_list RPAREN compound_statement "<<endl<<endl;
		outlog<<$1->get_name()<<" "<<$2->get_name()<<"("+$4->get_name()+")\n"<<$7->get_name()<<endl<<endl;
		$$ = new symbol_info($1->get_name() + " " + $2->get_name() + "(" + $4->get_name() + ")\n" + $7->get_name(), "func_def");
	}

	| type_specifier ID LPAREN RPAREN 
	{
		symbol_info* new_symbol = new symbol_info($2->get_name(), $2->get_type(), "Function Definition");
		new_symbol->set_data_type($1->get_name());
		main_table->insert(new_symbol);
		
		main_table->enter_scope();
		outlog << "New ScopeTable with ID " << main_table->getCurrentScopeID() << " created" << endl << endl;
	}
	
	compound_statement
	{			
		outlog<<"At line no: "<<lines<<" func_definition : type_specifier ID LPAREN RPAREN compound_statement "<<endl<<endl;
		outlog<<$1->get_name()<<" "<<$2->get_name()<<"()\n"<<$6->get_name()<<endl<<endl;
		$$ = new symbol_info($1->get_name()+" "+$2->get_name()+"()\n"+$6->get_name(),"func_def");	
	}
 	;

parameter_list: parameter_list COMMA type_specifier ID
	{
		outlog << "At line no: " << lines << " parameter_list : parameter_list COMMA type_specifier ID " << endl << endl;
		outlog << $1->get_name() << "," << $3->get_name() << " " << $4->get_name() << endl << endl;
		$$ = new symbol_info($1->get_name()+","+$3->get_name()+" "+$4->get_name(),"param_list");
		// store the necessary information about the function parameters
        // They will be needed when you want to enter the function into the symbol table
		$$->set_param_types($1->get_param_types()); 
    	$$->set_param_names($1->get_param_names()); 
    	$$->add_parameter($3->get_name(), $4->get_name());
	}
	
	| parameter_list COMMA type_specifier
	{
		outlog << "At line no: " << lines << " parameter_list : parameter_list COMMA type_specifier " << endl << endl;
		outlog << $1->get_name() << "," << $3->get_name() << endl << endl;
		$$ = new symbol_info($1->get_name() + "," + $3->get_name(), "param_list");
		$$->set_param_types($1->get_param_types()); //same reason 
    	$$->set_param_names($1->get_param_names()); 
    	$$->add_parameter($3->get_name(), ""); 
	}

	| type_specifier ID
	{
		outlog << "At line no: " << lines << " parameter_list : type_specifier ID " << endl << endl;
		outlog << $1->get_name() << " " << $2->get_name() << endl << endl;
		$$ = new symbol_info($1->get_name() + " " + $2->get_name(), "param_list");
		$$->add_parameter($1->get_name(), $2->get_name()); //same reason
	}

	| type_specifier
	{
		outlog << "At line no: " << lines << " parameter_list : type_specifier " << endl << endl;
		outlog << $1->get_name() << endl << endl;
		$$ = new symbol_info($1->get_name(), "param_list");
		$$->add_parameter($1->get_name(), ""); //same reason
	};

compound_statement: LCURL statements RCURL
	{
		outlog << "At line no: " << lines << " compound_statement : LCURL statements RCURL " << endl << endl;
		outlog << "{\n"+$2->get_name()+"\n}" << endl << endl;
		$$ = new symbol_info("{\n" + $2->get_name() + "\n}", "comp_stmnt");
		// Print the symbol table here and exit the scope and Note that function parameters should be in the current scope
		main_table->print_all_scopes(outlog); 
		int id = main_table->getCurrentScopeID(); 
    	main_table->exit_scope();
		outlog << "Scopetable with ID " << id << " removed" << endl << endl;
	}

	| LCURL RCURL
	{
		outlog << "At line no: " << lines << " compound_statement : LCURL RCURL " << endl << endl;
		outlog << "{\n}" << endl << endl;
		$$ = new symbol_info("{\n}", "compound_stmnt");
	};

//var_declaration: type_specifier declaration_list SEMICOLON
	//{
		//outlog << "At line no: " << lines << " var_declaration : type_specifier declaration_list SEMICOLON " << endl << endl;
		//outlog << $1->get_name() << " " << $2->get_name() << ";" << endl << endl;
		//$$ = new symbol_info($1->get_name() + " " + $2->get_name() + ";", "var_declaration");
		// Print the symbol table here and exit the scope
		//main_table->print_all_scopes(outlog); 
		//int id = main_table->getCurrentScopeID();
    	//main_table->exit_scope();
		//outlog << "Scopetable with ID " << id << " removed" << endl << endl;
	//};

var_declaration : type_specifier declaration_list SEMICOLON  // int a,b,c,d;
		 {
			outlog<<"At line no: "<<lines<<" var_declaration : type_specifier declaration_list SEMICOLON "<<endl<<endl;
			outlog<<$1->get_name()<<" "<<$2->get_name()<<";"<<endl<<endl;
			$$ = new symbol_info($1->get_name()+" "+$2->get_name()+";","var_dec");
			
		 	data_type = $1->get_name(); // Insert necessary information about the variables in the symbol table
			//symbol_type="Variable";
    		vector<string> vars = split($2->get_name(), ',');

			for (const string& var : vars) {
				size_t open_bracket = var.find('[');
				size_t close_bracket = var.find(']');

				if (open_bracket != string::npos && close_bracket != string::npos && close_bracket > open_bracket + 1) {
					string array_name = var.substr(0, open_bracket);
					string size_str = var.substr(open_bracket + 1, close_bracket - open_bracket - 1);
					int array_size = stoi(size_str);  

					symbol_info* new_symbol = new symbol_info(array_name, "ID", "Array");
					new_symbol->set_array_size(array_size);
					new_symbol->set_data_type(data_type);
					main_table->insert(new_symbol);
				} else { // Normal variable
					symbol_info* new_symbol = new symbol_info(var, "ID", "Variable");
					new_symbol->set_data_type(data_type);
					main_table->insert(new_symbol);
				}
			}
		 };

type_specifier : INT 
	{
		outlog << "At line no:" << lines << " type_specifier : INT "<< endl << endl;
		outlog << "int" << endl <<endl;
		$$ = new symbol_info("int", "type");
	}
	| FLOAT
	{   
		outlog<<"At line no: "<< lines <<" type_specifier: FLOAT "<<endl<<endl;
		outlog<<"float"<<endl<<endl;
		$$ = new symbol_info("float", "type");
	}
	| VOID
	{   
		outlog<<"At line no: "<< lines <<" type_specifier: VOID "<<endl<<endl;
		outlog<<"void"<<endl<<endl;
		$$ = new symbol_info("void", "type");
	};

declaration_list: declaration_list COMMA ID
	{
		outlog << "At line no: " << lines << " declaration_list : declaration_list COMMA ID " << endl << endl;
		outlog << $1->get_name() << "," << $3->get_name() << endl << endl;
	    $$ = new symbol_info($1->get_name() + "," + $3->get_name(), "declaration_list");
	}
	| declaration_list COMMA ID LTHIRD CONST_INT RTHIRD
	{
		outlog << "At line no: " << lines << " declaration_list : declaration_list COMMA ID LTHIRD CONST_INT RTHIRD " << endl << endl;
		outlog << $1->get_name() << "," << $3->get_name() << "[" << $5->get_name() << "]" << endl << endl;
		symbol_type="Array";
		array_size = stoi($5->get_name());
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

statements: statement
	{   
		outlog << "At line no: " << lines << " statements : statement " << endl << endl;
		outlog << $1->get_name() << endl << endl;
		$$ = new symbol_info($1->get_name(), "stmnts");
	}
	| statements statement
	{
		outlog << "At line no: " << lines << " statements : statements statement " << endl << endl;
		outlog << $1->get_name()<<"\n"<<$2->get_name() << endl << endl;
		$$ = new symbol_info($1->get_name() + "\n"+ $2->get_name(), "stmnts");
	};

statement: var_declaration
	{
		outlog << "At line no: " << lines << " statement : var_declaration " << endl << endl;
		outlog << $1->get_name() << endl << endl;
		$$ = new symbol_info($1->get_name(), "stmnt");
	}
	| func_definition
	{
	  	outlog<<"At line no: "<<lines<<" statement : func_definition "<<endl<<endl;
        outlog<<$1->get_name()<<endl<<endl;
        $$ = new symbol_info($1->get_name(),"stmnt");
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
	};

	| FOR LPAREN expression_statement expression_statement expression RPAREN scope_entry statement
	{
	    outlog<<"At line no: "<<lines<<" statement : FOR LPAREN expression_statement expression_statement expression RPAREN statement "<<endl<<endl;
		outlog<<"for("<<$3->get_name()<<$4->get_name()<<$5->get_name()<<")\n"<<$8->get_name()<<endl<<endl;
		$$ = new symbol_info("for("+$3->get_name()+$4->get_name()+$5->get_name()+")\n"+$8->get_name(),"stmnt");
	}

	| IF LPAREN expression RPAREN scope_entry statement %prec LOWER_THAN_ELSE 
	{
		outlog << "At line no: " << lines << " statement : IF LPAREN expression RPAREN statement " << endl << endl;
		outlog << "if(" << $3->get_name() << ")\n" << $6->get_name() << endl << endl;
		$$ = new symbol_info("if(" + $3->get_name() + ")\n" + $6->get_name(), "stmnt");
	}
	| IF LPAREN expression RPAREN scope_entry statement ELSE scope_entry statement
	{
		outlog << "At line no: " << lines << " statement : IF LPAREN expression RPAREN statement ELSE statement " << endl << endl;
		outlog << "if(" << $3->get_name() << ")\n" << $5->get_name() << "\nelse\n" << $7->get_name() << endl << endl;
		$$ = new symbol_info("if(" + $3->get_name() + ")\n" + $5->get_name() + "\nelse\n" + $7->get_name(), "stmnt");
	}
	| WHILE LPAREN expression RPAREN scope_entry statement
	{
		outlog << "At line no: " << lines << " statement : WHILE LPAREN expression RPAREN statement " << endl << endl;
		outlog << "while(" << $3->get_name() << ")\n" << $5->get_name() << endl << endl;
		$$ = new symbol_info("while(" + $3->get_name() + ")\n" + $5->get_name(), "stmnt");
	}
	| PRINTF LPAREN ID RPAREN SEMICOLON
	{
		outlog << "At line no: " << lines << " statement : PRINTF LPAREN ID RPAREN SEMICOLON " << endl << endl;
		outlog << "printf(" << $3->get_name() << ");" << endl << endl;
		$$ = new symbol_info("printf(" + $3->get_name() + ");", "stmnt");
	}
	| RETURN expression SEMICOLON
	{
		outlog << "At line no: " << lines << " statement : RETURN expression SEMICOLON " << endl << endl;
		outlog << "return " << $2->get_name() << ";" << endl << endl;
		$$ = new symbol_info("return " + $2->get_name() + ";", "stmnt");
	};

scope_entry : 
{
	main_table->enter_scope();
	outlog << "New ScopeTable with ID " << main_table->getCurrentScopeID() << " created" << endl << endl;
}

expression_statement: SEMICOLON
	{
		outlog << "At line no: " << lines << " expression_statement : SEMICOLON " << endl << endl;
		outlog<<";"<<endl<<endl;
	    $$ = new symbol_info(";", "expr_stmt");
	}
	| expression SEMICOLON
	{
		outlog << "At line no: " << lines << " expression_statement : expression SEMICOLON " << endl << endl;
		outlog << $1->get_name() << ";" << endl << endl;
	        $$ = new symbol_info($1->get_name() + ";", "expr_stmt");
	};

variable: ID
	{
		outlog << "At line no: " << lines << " variable : ID " << endl << endl;
		outlog << $1->get_name() << endl << endl;
	    $$ = new symbol_info($1->get_name(), "varabl");
	}
	| ID LTHIRD expression RTHIRD
	{
		outlog << "At line no: " << lines << " variable : ID LTHIRD expression RTHIRD " << endl << endl;
		outlog << $1->get_name() << "[" << $3->get_name() << "]" << endl << endl;
	    $$ = new symbol_info($1->get_name() + "[" + $3->get_name() + "]", "varabl");
	};

expression: logic_expression
	{
		outlog << "At line no: " << lines << " expression : logic_expression " << endl << endl;
		outlog << $1->get_name() << endl << endl;
	    $$ = new symbol_info($1->get_name(), "expr");
	}
	| variable ASSIGNOP logic_expression
	{
		outlog << "At line no: " << lines << " expression : variable ASSIGNOP logic_expression " << endl << endl;
		outlog << $1->get_name() << "=" << $3->get_name() << endl << endl;
	    $$ = new symbol_info($1->get_name() + "=" + $3->get_name(), "expr");
	};

logic_expression: rel_expression
	{
		outlog << "At line no: " << lines << " logic_expression : rel_expression " << endl << endl;
		outlog << $1->get_name() << endl << endl;
	    $$ = new symbol_info($1->get_name(), "lgc_expr");
	}
	| rel_expression LOGICOP rel_expression
	{
		outlog << "At line no: " << lines << " logic_expression : rel_expression LOGICOP rel_expression " << endl << endl;
		outlog << $1->get_name()<< $2->get_name()<< $3->get_name() << endl << endl;
	    $$ = new symbol_info($1->get_name() + $2->get_name() + $3->get_name(), "lgc_expr");
	};

rel_expression: simple_expression
	{
		outlog << "At line no: " << lines << " rel_expression : simple_expression " << endl << endl;
		outlog << $1->get_name() << endl << endl;
	    $$ = new symbol_info($1->get_name(), "rel_expr");
	}
	| simple_expression RELOP simple_expression
	{
		outlog << "At line no: " << lines << " rel_expression : simple_expression RELOP simple_expression " << endl << endl;
		outlog << $1->get_name() << $2->get_name() <<  $3->get_name() << endl << endl;
	    $$ = new symbol_info($1->get_name() +  $2->get_name() +  $3->get_name(), "rel_expr");
	};

simple_expression: term
	{
		outlog << "At line no: " << lines << " simple_expression : term " << endl << endl;
		outlog << $1->get_name() << endl << endl;
		$$ = new symbol_info($1->get_name(), "simp_expr");
	}
	| simple_expression ADDOP term
	{
		outlog << "At line no: " << lines << " simple_expression : simple_expression ADDOP term " << endl << endl;
		outlog << $1->get_name() << $2->get_name() << $3->get_name() << endl << endl;
	    $$ = new symbol_info($1->get_name() + $2->get_name() + $3->get_name(), "simp_expr");
	};

term: unary_expression
	{
		outlog << "At line no: " << lines << " term : unary_expression " << endl << endl;
		outlog << $1->get_name() << endl << endl;
	        $$ = new symbol_info($1->get_name(), "term");
	}
	| term MULOP unary_expression
	{
		outlog << "At line no: " << lines << " term : term MULOP unary_expression " << endl << endl;
		outlog << $1->get_name()  << $2->get_name() <<  $3->get_name() << endl << endl;
	    $$ = new symbol_info($1->get_name()  + $2->get_name() +  $3->get_name(), "term");
	};

unary_expression: ADDOP unary_expression
	{
		outlog << "At line no: " << lines << " unary_expression : ADDOP unary_expression " << endl << endl;
		outlog << $1->get_name() << $2->get_name() << endl << endl;
	    $$ = new symbol_info($1->get_name() + $2->get_name(), "un_expr");
	}
	| NOT unary_expression
	{
		outlog << "At line no: " << lines << " unary_expression : NOT unary_expression " << endl << endl;
		outlog<<"!"<<$2->get_name()<<endl<<endl;
	    $$ = new symbol_info("!" + $2->get_name(), "un_expr");
	}
	| factor
	{
		outlog << "At line no: " << lines << " unary_expression : factor " << endl << endl;
		outlog << $1->get_name() << endl << endl;
	    $$ = new symbol_info($1->get_name(), "un_expr");
	};

factor: variable
	{
		outlog << "At line no: " << lines << " factor : variable " << endl << endl;
		outlog << $1->get_name() << endl << endl;
	    $$ = new symbol_info($1->get_name(), "fctr");
	}
	| ID LPAREN argument_list RPAREN
	{
		outlog << "At line no: " << lines << " factor : ID LPAREN argument_list RPAREN " << endl << endl;
		outlog << $1->get_name() << "(" << $3->get_name() << ")" << endl << endl;
	    $$ = new symbol_info($1->get_name() + "(" + $3->get_name() + ")", "fctr");
	}
	| LPAREN expression RPAREN
	{
		outlog << "At line no: " << lines << " factor : LPAREN expression RPAREN " << endl << endl;
		outlog << "(" << $2->get_name() << ")" << endl << endl;
	    $$ = new symbol_info("(" + $2->get_name() + ")", "fctr");
	}
	| CONST_INT
	{
		outlog << "At line no: " << lines << " factor : CONST_INT " << endl << endl;
		outlog << $1->get_name() << endl << endl;
	        $$ = new symbol_info($1->get_name(), "fctr");
	}
	| CONST_FLOAT
	{
		outlog << "At line no: " << lines << " factor : CONST_FLOAT " << endl << endl;
		outlog << $1->get_name() << endl << endl;
	        $$ = new symbol_info($1->get_name(), "fctr");
	}
	| variable INCOP
	{
		outlog << "At line no: " << lines << " factor : variable INCOP " << endl << endl;
		outlog << $1->get_name() << "++" << endl << endl;
	        $$ = new symbol_info($1->get_name() + "++", "fctr");
	}
	| variable DECOP
	{
		outlog << "At line no: " << lines << " factor : variable DECOP " << endl << endl;
		outlog << $1->get_name() << "--" << endl << endl;
	        $$ = new symbol_info($1->get_name() + "--", "fctr");
	};

argument_list: arguments
	{
		outlog << "At line no: " << lines << " argument_list : arguments " << endl << endl;
		outlog << $1->get_name() << endl << endl;
	    $$ = new symbol_info($1->get_name(), "arg_list");
	}
	|
	{
		outlog << "At line no: " << lines << " argument_list : " << endl << endl;
	    $$ = new symbol_info("", "arg_list");
	};

arguments: arguments COMMA logic_expression
	{
		outlog << "At line no: " << lines << " arguments : arguments COMMA logic_expression " << endl << endl;
		outlog << $1->get_name() << ", " << $3->get_name() << endl << endl;
	    $$ = new symbol_info($1->get_name() + ", " + $3->get_name(), "arg");
	}
	| logic_expression
	{
		outlog << "At line no: " << lines << " arguments : logic_expression " << endl << endl;
		outlog << $1->get_name() << endl << endl;
	    $$ = new symbol_info($1->get_name(), "arg");
	};

%%

int main(int argc, char *argv[])
{
	if(argc != 2) 
	{
		cout<<"Please input file name"<<endl;
		return 0;
	}
	yyin = fopen(argv[1], "r");
	outlog.open("21301242_log.txt", ios::trunc);
	
	if(yyin == NULL)
	{
		cout<<"Couldn't open file"<<endl;
		return 0;
	}

	main_table = new symbol_table(10); // Enter the global or the first scope here
  	//main_table->enter_scope(); 
	outlog << "New ScopeTable with ID " << main_table->getCurrentScopeID() << " created" << endl << endl;
	yyparse();
	
	outlog<<endl<<"Total lines: "<<lines<<endl;
	
	outlog.close();
	
	fclose(yyin);
	
	return 0;
}
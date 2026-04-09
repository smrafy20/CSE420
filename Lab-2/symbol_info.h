#include<bits/stdc++.h>
using namespace std;


class symbol_info
{
private:
    string name;
    string type;
    string data_type;
    vector<string> parameter_types;
    vector<string> parameter_names;
    int array_size;
    string symbol_type;

    // Write necessary attributes to store what type of symbol it is (variable/array/function)
    // Write necessary attributes to store the type/return type of the symbol (int/float/void/...)
    // Write necessary attributes to store the parameters of a function
    // Write necessary attributes to store the array size if the symbol is an array

public:
    symbol_info(string name, string type , string symbol_type="" , vector<string> parameter_types = vector<string>(),vector<string> parameter_names = vector<string>() )
    {
        this->name = name;
        this->type = type;
        this->symbol_type = symbol_type;
        this->array_size=0;
        this->parameter_types = parameter_types;
        this->parameter_names = parameter_names;
    }

    //Functions to set the attributes
    void set_name(string name)
    {
        this->name = name;
    }

    void set_type(string type)
    {
        this->type = type;
    }

    void set_symbol_type(string symbol_type)
    {
        this->symbol_type=symbol_type;
    }

    void set_data_type(string data_type)
    {
        this->data_type=data_type;
    }

    void set_array_size(int size)
    { 
        this->array_size = size; 
    }

    void set_param_names(const vector<string>& names)
    { 
        parameter_names = names; 
    }

    void set_param_types(const vector<string>& types)
    { 
        parameter_types = types; 
    }

    void add_parameter(string type, string name)
    {
        parameter_types.push_back(type);
        parameter_names.push_back(name);
    }

    // Functions to fetch the attributes
    string get_name()
    {
        return name;
    }

    string get_type()
    {
        return type;
    }

    string get_symbol_type()
    { 
        return symbol_type; 
    }

    string get_data_type()
    {
        return data_type;
    }

    int get_array_size()
    { 
        return array_size; 
    }

    vector<string> get_param_types() // vector is list like in python.
    { 
        return parameter_types; 
    }

    vector<string> get_param_names()
    { 
        return parameter_names; 
    }

    ~symbol_info()
    {
        // Write necessary code to deallocate memory, if necessary
    }
};
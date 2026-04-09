#include "symbol_info.h"


class scope_table
{
private:
    int bucket_count;
    int unique_id;
    scope_table *parent_scope = NULL;
    vector<list<symbol_info *>> table;

    int hash_function(string name)
    {
        int count= 0;
        for (char i : name){
            count += static_cast<int>(i);
        }
        return count % bucket_count; //returning the hash index for the name
    }

public:
    scope_table(int n) : bucket_count(n), unique_id(0), parent_scope(nullptr), table(vector<list<symbol_info *>>(n)) {}
    scope_table(int bucket_count, int unique_id, scope_table *parent_scope){
        this->bucket_count = bucket_count;    
        this->unique_id = unique_id;          
        this->parent_scope = parent_scope;   
        this->table = vector<list<symbol_info*>>(bucket_count);
    }

    scope_table *get_parent_scope(){
        return parent_scope;
    }
    int get_unique_id(){
        return unique_id;
    }

    symbol_info *lookup_in_scope(symbol_info* symbol){
        //checking if a symbol exists or not in the current scope table
        string symbol_name = symbol->get_name();
        int idx= hash_function(symbol_name);
        for (auto& values : table[idx]){
            if (values->get_name() == symbol->get_name()) {
                return values;
            }
        }
        return nullptr;
    }

    bool insert_in_scope(symbol_info* symbol){
        //inserting in the scope table
        auto found= lookup_in_scope(symbol);
        if (!found){
            string symbol_name = symbol->get_name();
            int idx = hash_function(symbol_name);
            table[idx].push_back(symbol);
            return true;
        }
        return false;
    }

    bool delete_from_scope(symbol_info* symbol){
        //deleting from scope table
        string symbol_name = symbol->get_name();
        int index = hash_function(symbol_name);

        auto& instances = table[index]; //instances is basically the bucket(list)
        for (auto values = instances.begin(); values != instances.end(); ++values) {
            if ((*values)->get_name() == symbol->get_name()) {
                delete *values;  //free the memory
                instances.erase(values);  //remove from the list
                return true;
            }
        }
        return false;
    }
    void print_scope_table(ofstream& outlog);

    ~scope_table(){
        for (auto &bucket : table){
            for (auto symbol : bucket){
                delete symbol; //free the memory
                symbol= nullptr;
            }
        }
    }

    // you can add more methods if you need
};


// complete the methods of scope_table class
void scope_table::print_scope_table(ofstream& outlog)
{
    outlog << "ScopeTable # " << unique_id <<endl;
    for (int i = 0; i < bucket_count; ++i) {
        if (!table[i].empty()) {
            outlog << i << "--> " << endl;
            for (auto symbol : table[i]) {
                outlog << "< " << symbol->get_name() << " : " << symbol->get_type() << " > " << endl;
                outlog  << symbol->get_symbol_type()  << endl;
                

                if(symbol->get_symbol_type()=="Function Definition"){
                    outlog << "Return Type : " << symbol->get_data_type() << endl;
                
                        auto types = symbol->get_param_types();
                        auto names = symbol->get_param_names();
                        
                        outlog << "Number of Parameters: " << types.size() << endl;
                    
                        
                        outlog << "Parameter Details: ";
                        for (size_t i = 0; i < types.size(); ++i) {
                            outlog << types[i] << " " << names[i];
                            if (i != types.size() - 1) {  
                                outlog << ", ";
                            }
                        }
                        outlog << endl;
                    }else{
                        int array_size = symbol->get_array_size() ;
                        if(array_size!=0){
                            outlog << "Type : " << symbol->get_data_type() << endl;
                            outlog << "Size : " << array_size << endl;

                        }else{
                        outlog << "Type : " << symbol->get_data_type() << endl;
                        }
                    }
            outlog << endl ;
        }
    }
}
}
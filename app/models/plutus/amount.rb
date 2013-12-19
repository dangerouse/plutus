module Plutus
  # The Amount class represents debit and credit amounts in the system.
  #
  # @abstract
  #   An amount must be a subclass as either a debit or a credit to be saved to the database. 
  #
  # @author Michael Bulat
  class Amount < ActiveRecord::Base
    attr_accessible :account, :account_name, :amount, :transaction

    belongs_to :transaction
    belongs_to :account


    belongs_to :account
    attr_accessible :account, :amount

    validates_presence_of :type, :amount, :transaction, :account


     # Assign an account by name                                                                                   
    def account_name=(name)
      self.account = Account.where(name: name).first
    end
    
    protected                                                                                                     
                                                                                                                   
    # Support constructing amounts with account = "name" syntax                                                   
    def account_with_name_lookup=(v)                                                                              
      if v.kind_of?(String)                                                                                       
        ActiveSupport::Deprecation.warn("Plutus was given an :account String (use account_name instead)", caller) 
        self.account_name = v                                                                                     
      else                                                                                                        
        self.account_without_name_lookup = v                                                                      
      end                                                                                                         
    end                                                                                                           
    alias_method_chain :account=, :name_lookup                                                                    
  end
end

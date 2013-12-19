module Plutus
  # Transactions are the recording of debits and credits to various accounts.
  # This table can be thought of as a traditional accounting Journal.
  #
  # Posting to a Ledger can be considered to happen automatically, since
  # Accounts have the reverse 'has_many' relationship to either it's credit or
  # debit transactions
  #
  # @example
  #   cash = Plutus::Asset.find_by_name('Cash')
  #   accounts_receivable = Plutus::Asset.find_by_name('Accounts Receivable')
  #
  #   debit_amount = Plutus::DebitAmount.new(:account => cash, :amount => 1000)
  #   credit_amount = Plutus::CreditAmount.new(:account => accounts_receivable, :amount => 1000)
  #
  #   transaction = Plutus::Transaction.new(:description => "Receiving payment on an invoice")
  #   transaction.debit_amounts << debit_amount
  #   transaction.credit_amounts << credit_amount
  #   transaction.save
  #
  # @see http://en.wikipedia.org/wiki/Journal_entry Journal Entry
  #
  # @author Michael Bulat
  class Transaction < ActiveRecord::Base
    belongs_to :commercial_document, :polymorphic => true
    has_many :credit_amounts, :inverse_of => :transaction, :extend => AmountsExtension
    has_many :debit_amounts, :inverse_of => :transaction, :extend => AmountsExtension
    has_many :credit_accounts, :through => :credit_amounts, :source => :account
    has_many :debit_accounts, :through => :debit_amounts, :source => :account


    belongs_to :invoice

    attr_accessible :description, :invoice
    attr_accessible :commercial_document, :created_at, :updated_at
    attr_accessible :debits, :credits


    validates_presence_of :description
    validate :has_credit_amounts?
    validate :has_debit_amounts?
    validate :amounts_cancel?
    
    # Support construction using 'credits' and 'debits' keys
    accepts_nested_attributes_for :credit_amounts, :debit_amounts
    alias_method :credits=, :credit_amounts_attributes=
    alias_method :debits=, :debit_amounts_attributes=
    attr_accessible :credits, :debits

    
    # Support the deprecated .build method
    def self.build(hash)
      ActiveSupport::Deprecation.warn("Plutus::Transaction.build() is deprecated (use new instead)", caller)
      new(hash)
    end

    def total_credits                 
      self.credit_amounts.sum :amount 
    end                               
    
    def total_debits                  
      self.debit_amounts.sum :amount  
    end                               
    
    def inverted?                     
      total_debits < 0                
    end
    
    def reverse(_opts = {})
      # collect all the amounts and clone them for this transaction, with reversed
      _debits = debit_amounts.map(&:clone)
      _credits = credit_amounts.map(&:clone)
      (_debits + _credits).each { |amount| amount.update_attribute(:amount, -(amount.amount)) }
      _transaction                = self.clone
      _transaction.created_at     = _transaction.updated_at = Time.now
      _transaction.debit_amounts  = _debits
      _transaction.credit_amounts = _credits
      _transaction.update_attributes(_opts)
      _transaction
    end
    
    def adjust_charge(_opts = {})
      if _opts[:amount]
        self.debit_amounts.last.update_attribute :amount, _opts[:amount]
        self.credit_amounts.last.update_attribute :amount, _opts[:amount]
      else
        self.update_attributes :description => _opts[:description] || "Free development-only domain"
        self.debit_amounts.last.update_attribute :amount, 0.0
        self.credit_amounts.last.update_attribute :amount, 0.0
      end
    end

    private
    
    def has_credit_amounts?
      errors[:base] << "Transaction must have at least one credit amount" if self.credit_amounts.blank?
    end

    def has_debit_amounts?
      errors[:base] << "Transaction must have at least one debit amount" if self.debit_amounts.blank?
    end

    def amounts_cancel?
      errors[:base] << "The credit and debit amounts are not equal" if credit_amounts.balance != debit_amounts.balance
    end
  end
end

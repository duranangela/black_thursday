require_relative 'sales_engine.rb'
require 'pry'

class SalesAnalyst

  def initialize(sales_engine)
    @items = sales_engine.items
    @merchants = sales_engine.merchants
    @invoices = sales_engine.invoices
    @transactions = sales_engine.transactions
    @invoice_items = sales_engine.invoice_items
    @id_counts = {}
    @average_items = average_items_per_merchant
    @items_standard_deviation = average_items_per_merchant_standard_deviation
    @average_item_price = average_total_item_price
    @price_standard_deviation = item_price_standard_deviation
    @average_invoices = average_invoices_per_merchant
    @invoice_standard_deviation = average_invoices_per_merchant_standard_deviation
  end

  def average_items_per_merchant
    sum = items_per_merchant.reduce(0.0) do |total, count|
      total += count
    end
    average = (sum / items_per_merchant.length).round(2)
  end

  def average_items_per_merchant_standard_deviation
    standard_deviation(items_per_merchant, @average_items)
  end

  def standard_deviation(array, average)
    count_less_one = (array.count - 1)
    sum = array.reduce(0.0) do |total, amount|
      total += (amount - average) ** 2
    end
    standard_deviation = ((sum / count_less_one) ** (1.0/2)).round(2)
  end

  def items_grouped_by_merchant
    @items.all.group_by do |item|
      item.merchant_id
    end
  end

  def items_per_merchant
    array_of_arrays_of_items_per_merchant = items_grouped_by_merchant.values
    array_of_arrays_of_items_per_merchant.map do |array|
      array = array.count
    end
  end

  def id_counts
    items_grouped_by_merchant.keys.zip(items_per_merchant)
  end

  def merchants_with_high_item_count
    high_count = @average_items + @items_standard_deviation
    good_merchants = id_counts.map do |id, count|
      if count >= high_count
        @merchants.find_by_id(id)
      end
    end
    good_merchants.compact
  end

  def average_item_price_for_merchant(id)
    items = @items.find_all_by_merchant_id(id)
    sum = items.reduce(0) do |total, item|
      total += item.unit_price
    end
    (sum / items.count).round(2)
  end


  def average_average_price_per_merchant
    sum = @merchants.all.reduce(0) do |total, merchant|
      total += average_item_price_for_merchant(merchant.id)
    end
    (sum / @merchants.repository.count).round(2)
  end

  def average_item_prices_for_each_merchant
    @merchants.all.map do |merchant|
      merchant = average_item_price_for_merchant(merchant.id)
    end
  end

  def item_price_standard_deviation
    standard_deviation(all_item_prices, @average_item_price).round(2)
  end

  def all_item_prices
    @items.all.map do |item|
      item = item.unit_price
    end
  end

  def average_total_item_price
    sum = @items.all.reduce(0) do |total, item|
      total += item.unit_price
    end
    sum / @items.all.count
  end

  def golden_items
    high_price = @average_item_price + (@price_standard_deviation * 2)
    golden_items = @items.all.reduce([]) do |array, item|
      array << item if item.unit_price >= high_price
      array
    end
    golden_items
  end

  ###### Invoices begin below, the copy and paste shows we arent DRY.

  ###### Invoices by merchant section
  def invoices_grouped_by_merchant
    @invoices.all.group_by do |invoice|
      invoice.merchant_id
    end
  end

  def invoices_per_merchant
    array_of_arrays_of_invoices_per_merchant = invoices_grouped_by_merchant.values
    array_of_arrays_of_invoices_per_merchant.map do |array|
      array = array.count
    end
  end

  def average_invoices_per_merchant
    sum = invoices_per_merchant.reduce(0.0) do |total, count|
      total += count
    end
    average = (sum / invoices_per_merchant.length).round(2)
  end

  def average_invoices_per_merchant_standard_deviation
    standard_deviation(invoices_per_merchant, @average_invoices)
  end

  def invoice_counts_for_each_merhant
    invoices_grouped_by_merchant.merge(invoices_grouped_by_merchant) do |id, invoices|
      invoices.count
    end
  end

  def top_merchants_by_invoice_count
    high_count = @average_invoices + (@invoice_standard_deviation * 2)
    top_merchants = invoice_counts_for_each_merhant.map do |id, count|
        @merchants.find_by_id(id) if count > high_count
    end
    top_merchants.compact
  end

  def bottom_merchants_by_invoice_count
    low_count = @average_invoices - (@invoice_standard_deviation * 2)
    bottom_merchants = invoice_counts_for_each_merhant.map do |id, count|
        @merchants.find_by_id(id) if count < low_count
    end
    bottom_merchants.compact
  end

######### Invoices by day section

  def invoices_grouped_by_day
    @invoices.all.group_by do |invoice|
      invoice.created_at.strftime("%A")
    end
  end

  def invoices_per_day
    array_of_arrays_of_invoices_per_day = invoices_grouped_by_day.values
    array_of_arrays_of_invoices_per_day.map do |array|
      array = array.count
    end
  end

  def average_invoices_per_day
    sum = invoices_per_day.reduce(0.0) do |total, count|
      total += count
    end
    average = (sum / invoices_per_day.length).round(2)
  end

  def average_invoices_per_day_standard_deviation
    standard_deviation(invoices_per_day, average_invoices_per_day)
  end

  def invoice_counts_for_each_day
    invoices_grouped_by_day.merge(invoices_grouped_by_day) do |day, invoices|
      invoices.count
    end
  end

  def top_days_by_invoice_count
    high_count = average_invoices_per_day + average_invoices_per_day_standard_deviation
    top_days = invoice_counts_for_each_day.map do |day, count|
        day if count > high_count
    end
    top_days.compact
  end

  def invoices_grouped_by_status
    @invoices.all.group_by do |invoice|
      invoice.status
    end
  end

  def invoice_counts_for_each_status
    invoices_grouped_by_status.merge(invoices_grouped_by_status) do |day, invoices|
      invoices.count
    end
  end

  def invoice_status(status)
    count = invoice_counts_for_each_status[status].to_f
    total = @invoices.all.count.to_f
    ((count / total) * 100).round(2)
  end

############ Transaction methods

  def invoice_paid_in_full?(invoice_id)
    related_transactions = @transactions.find_all_by_invoice_id(invoice_id)
    if related_transactions.any? do |transaction|
      transaction.result == :success
      end
      true
    else
      false
    end
  end

  def invoice_total(invoice_id)
    related_invoice_items = @invoice_items.find_all_by_invoice_id(invoice_id)
    costs = related_invoice_items.map do |invoice_item|
      invoice_item.quantity * invoice_item.unit_price
    end
    total = costs.inject(0) do |total, cost|
      total += cost
    end
    amount = BigDecimal.new(total, 7)
  end

########### Iteration 4 methods

  def total_revenue_by_date(date)
    invoices = find_all_invoices_created_at_date(date)
    invoices.inject(0) do |total, invoice|
      total += invoice_total(invoice.id) if invoice_paid_in_full?(invoice.id)
      total
    end
  end

  def find_all_invoices_created_at_date(date)
    @invoices.all.select do |invoice|
      if invoice.created_at.strftime('%d%m%y') == date.strftime('%d%m%y')
        invoice
      end
    end
  end

  def total_revenue_for_each_merchant
    earners = {}
    invoices_grouped_by_merchant.each do |merchant_id, invoices|
      earners[merchant_id] = invoices.map do |invoice|
        if invoice_paid_in_full?(invoice.id)
          invoice_total(invoice.id)
        end
      end.compact.inject(:+)
    end
    earners
  end

  def merchants_with_a_sale
    total_revenue_for_each_merchant.keep_if do |merchant_id, earned|
      earned != nil
    end
  end

  def hash_to_array_ordered_by_value(hash)
    sorted_values = hash.values.sort
    array = []
    sorted_values.each do |value|
      hash.each do |key, pair_value|
        array << key if pair_value == value
      end
    end
    array.uniq
  end

  def top_revenue_earners(num = 20)
    merchants_with_a_sale.keep_if do |merchant_id, earned|
      sorted_merchants = merchants_with_a_sale.values.sort
      sorted_merchants[-num..-1].include?(earned)
    end
    top_merchants = hash_to_array_ordered_by_value(merchants_with_a_sale)
    top_merchants.map do |merchant_id|
      @merchants.find_by_id(merchant_id)
    end.reverse
  end

  def revenue_by_merchant(merchant_id)
    total_revenue_for_each_merchant[merchant_id]
  end

  def merchants_with_pending_invoices
    merchant_ids = invoices_grouped_by_status[:pending].map do |invoice|
      invoice.merchant_id
    end
    merchant_ids.map do |merchant_id|
      @merchants.find_by_id(merchant_id)
    end.uniq
  end

end

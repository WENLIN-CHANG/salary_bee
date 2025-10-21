require 'rails_helper'

RSpec.describe 'shared/_flash.html.erb', type: :view do
  before do
    # 確保 helper method 可用
    allow(view).to receive(:flash_css_class) do |type|
      case type.to_s
      when 'alert', 'error'
        'brutalist-error'
      when 'notice', 'success'
        'brutalist-success'
      when 'warning'
        'brutalist-warning'
      else
        'brutalist-info'
      end
    end
  end

  context 'when there is a single alert message' do
    it 'displays the alert message with Neubrutalism styling and Alpine.js controls' do
      allow(view).to receive(:flash).and_return({ alert: 'Error message' })

      render

      expect(rendered).to include('Error message')
      expect(rendered).to include('brutalist-error')
      expect(rendered).to include('x-data="{ show: true }"')
      expect(rendered).to include('x-show="show"')
      expect(rendered).to include('x-init="setTimeout(() => show = false, 5000)"')
      expect(rendered).to include('@click="show = false"')
    end

    it 'includes a close button' do
      allow(view).to receive(:flash).and_return({ alert: 'Error message' })

      render

      expect(rendered).to include('×')
      expect(rendered).to include('關閉')
    end
  end

  context 'when there is a single notice message' do
    it 'displays the notice message with Neubrutalism styling and Alpine.js controls' do
      allow(view).to receive(:flash).and_return({ notice: 'Success message' })

      render

      expect(rendered).to include('Success message')
      expect(rendered).to include('brutalist-success')
      expect(rendered).to include('x-data="{ show: true }"')
    end
  end

  context 'when there are multiple flash messages' do
    it 'displays both alert and notice messages with their respective Neubrutalism styles' do
      allow(view).to receive(:flash).and_return({
        alert: 'Error message',
        notice: 'Success message'
      })

      render

      expect(rendered).to include('Error message')
      expect(rendered).to include('Success message')
      expect(rendered).to include('brutalist-error')
      expect(rendered).to include('brutalist-success')
    end

    it 'each message has its own Alpine.js state' do
      allow(view).to receive(:flash).and_return({
        alert: 'Error message',
        notice: 'Success message'
      })

      render

      # 應該有兩個獨立的 x-data 實例
      expect(rendered.scan(/x-data="{ show: true }"/).count).to eq(2)
    end
  end

  context 'when flash is empty' do
    it 'renders only the fixed container wrapper' do
      allow(view).to receive(:flash).and_return({})

      render

      expect(rendered).to include('fixed top-4 left-1/2')
      # 但不應該有任何 flash 訊息的 div
      expect(rendered).not_to include('x-data="{ show: true }"')
    end
  end

  context 'when flash contains nil or empty messages' do
    it 'does not render content for nil or empty messages' do
      allow(view).to receive(:flash).and_return({ alert: nil, notice: '' })

      render

      expect(rendered).not_to include('x-data="{ show: true }"')
    end
  end

  context 'when flash contains HTML content' do
    it 'properly escapes HTML content' do
      allow(view).to receive(:flash).and_return({
        alert: '<script>alert("xss")</script>'
      })

      render

      expect(rendered).to include('&lt;script&gt;')
      expect(rendered).to include('&lt;/script&gt;')
      expect(rendered).not_to include('<script>alert')
    end
  end

  context 'when flash contains long messages' do
    it 'handles long messages properly with Neubrutalism styling' do
      long_message = 'This is a very long message that should be handled properly by the flash partial without breaking the layout or causing any display issues.'
      allow(view).to receive(:flash).and_return({ notice: long_message })

      render

      expect(rendered).to include(long_message)
      expect(rendered).to include('brutalist-success')
    end
  end

  context 'Alpine.js transitions' do
    it 'includes transition attributes for smooth animations' do
      allow(view).to receive(:flash).and_return({ alert: 'Test message' })

      render

      expect(rendered).to include('x-transition:enter=')
      expect(rendered).to include('x-transition:leave=')
    end
  end

  context 'fixed positioning container' do
    it 'uses fixed positioning for toast-style notifications' do
      allow(view).to receive(:flash).and_return({ notice: 'Test' })

      render

      expect(rendered).to include('fixed top-4 left-1/2')
    end
  end
end

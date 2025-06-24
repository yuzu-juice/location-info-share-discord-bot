import { useState } from 'react'
import axios from 'axios'
import './App.css'

function App() {
  const [isLoading, setIsLoading] = useState(false)

  const handleButtonClick = async () => {
    if (!navigator.geolocation) {
      alert('このブラウザは位置情報をサポートしていません')
      return
    }

    setIsLoading(true)

    try {
      const position = await new Promise<GeolocationPosition>((resolve, reject) => {
        navigator.geolocation.getCurrentPosition(resolve, reject)
      })

      const latitude = position.coords.latitude
      const longitude = position.coords.longitude

      await axios.post('https://hono-location-info-share-discord-bot.yuzu-juice.workers.dev/post', {
        latitude: latitude,
        longitude: longitude,
        pinLatitude: latitude,
        pinLongitude: longitude,
        zoom: 15,
        message: '生存報告です！'
      })

      alert('送信しました！')
    } catch (error) {
      console.error('Error:', error)
      alert('送信に失敗しました')
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <div className="app-container">
      <button
        className="round-button"
        onClick={handleButtonClick}
        disabled={isLoading}
      >
        {isLoading ? '送信中...' : '生存報告'}
      </button>
    </div>
  )
}

export default App

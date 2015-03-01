ANIMATION_DURATION = 300
ANIMATION_INTERVAL = 20
TAN30 = Math.tan(Math.PI/6)
OUTER_RING_RADIUS = 0.95
INNER_RING_RADIUS = 0.7
RING_WIDTH = 1/200
HEXAGONS_HIGH = 55
SCREEN_RATIO = 16/9 # 16:9 ratio
SMALL_HEXAGONS_HIGH = 75
CIRCLE_SEGMENTS = 32
OUTER_ZOOM_FACTOR = 1.11
INNER_ZOOM_FACTOR = 1.06
INNER_BUMP_R = 0.7

distanceFromCenter = (v) ->
  (v[0] ** 2 + v[1] ** 2) ** 0.5

class Decal
  ###
   4___A___1  bigR
    |  N  |
    |  G  |
    |  L  |
    |__E__|
   3       2  littleR
  ###
  constructor: (@r, @angle, @large) ->

  data: (n) ->
    smallAngle = Math.PI / 1500
    factor = 1/10
    if @large
      smallAngle *= 2
      factor *= 2
    bigR = @r
    smallR = @r - (OUTER_RING_RADIUS - INNER_RING_RADIUS) * factor
    verticies = [
      [bigR * Math.sin(@angle + smallAngle), bigR * Math.cos(@angle + smallAngle)]
      [smallR * Math.sin(@angle + smallAngle), smallR * Math.cos(@angle + smallAngle)]
      [smallR * Math.sin(@angle - smallAngle), smallR * Math.cos(@angle - smallAngle)]
      [bigR * Math.sin(@angle - smallAngle), bigR * Math.cos(@angle - smallAngle)]
    ]

    faces = [
      [1, 2, 3]
      [1, 3, 4]
    ]

    # ==================================================
    # Output

    facesData = []
    verticiesData = []
    for face in faces
      for point in face
        facesData.push point - 1 + n

    for [x, y], i in verticies
      verticiesData.push x
      verticiesData.push y
    return verticiesData: verticiesData, facesData: facesData

class Hexagon
  ###
     1 ____ 2
     /|\  /|\
   6/ | \/ | \3
    \ | /\ | /
    5\|/__\|/4
  ###
  constructor: (@x, @y, @size, @maxRadius, @minRadius, @zoomFactor) ->

  data: (n) ->
    edgeLength = @size
    # T = O / A
    # T(30) = edgeLength/2 / A
    # A = edgeLength / (2 * Tan(30))
    hexHeight = edgeLength / TAN30

    verticies = [
      [@x - edgeLength / 2, @y + hexHeight / 2]
      [@x + edgeLength / 2, @y + hexHeight / 2]
      [@x + edgeLength,     @y]
      [@x + edgeLength / 2, @y - hexHeight / 2]
      [@x - edgeLength / 2, @y - hexHeight / 2]
      [@x - edgeLength,     @y]
    ]

    faces = [
      [1, 4, 2]
      [2, 4, 3]
      [1, 5, 4]
      [1, 6, 5]
    ]

    # ==================================================
    # Filtering
    fullyInside = true
    fullyOutside = true

    for vertex in verticies
      r = distanceFromCenter(vertex)
      isInside = (@minRadius <= r <= @maxRadius)
      vertex.push isInside
      fullyInside = fullyInside && isInside
      fullyOutside = fullyOutside && !isInside

    if fullyOutside
      verticies = []
      faces = []
    else if fullyInside
      # Noop
    else

      minR = @minRadius
      maxR = @maxRadius
      bestGuess = (vertex, otherVertex) ->
        # find the point along the line previousVertex..vertex where r hits the edge
        if minR <= distanceFromCenter(vertex) <= maxR
          # Vertex must be the OOB vertex
          [otherVertex, vertex] = [vertex, otherVertex]
        guess = vertex.slice()
        badBound = vertex.slice()
        goodBound = otherVertex.slice()

        moveToward = (v) ->
          guess[0] = (guess[0] + v[0]) / 2
          guess[1] = (guess[1] + v[1]) / 2
          return

        moveToward(goodBound)

        for i in [0..5]
          if minR <= distanceFromCenter(guess) <= maxR
            goodBound = guess.slice()
            moveToward badBound
          else
            badBound = guess.slice()
            moveToward goodBound
        return guess

      goodVerticies = []
      previousVertex = verticies[5]
      for vertex in verticies
        if previousVertex[2] isnt vertex[2]
          # One of them is outside
          goodVerticies.push bestGuess(vertex, previousVertex)
        if vertex[2]
          goodVerticies.push vertex
        previousVertex = vertex

      verticies = goodVerticies
      faces = ([1, i, i+1] for i in [2...verticies.length])


    # ==================================================
    # Output

    facesData = []
    verticiesData = []
    if faces.length > 0
      for face in faces
        for point in face
          facesData.push point - 1 + n

      px = @x / @zoomFactor
      py = @y / @zoomFactor
      for [x, y], i in verticies
        verticiesData.push x
        verticiesData.push y
        verticiesData.push px
        verticiesData.push py
    return verticiesData: verticiesData, facesData: facesData

class App
  VERTEX: 2
  FRAGMENT: 3

  colourAdjustmentDeclarations = """
    vec3 pixelColour;
    float contrast = 0.8;
    float brightness = 0.15;
    """

  colourAdjustmentCode = """
    pixelColour = vec3(raw);
    pixelColour += brightness;
    pixelColour = ((pixelColour - 0.5) * max(contrast, 0.)) + 0.5;
    pixelColour.x /= 2.;
    pixelColour.x -= 0.3;
    pixelColour.y -= 0.15;
    pixelColour.z *= 0.55;
    pixelColour.z += 0.45;

    gl_FragColor = vec4(pixelColour, 1.0);
    """

  hexagonVertexShaderSource: """
    attribute vec2 position;
    attribute vec2 texPosition;
    uniform float factor;
    uniform float screenRatio;
    varying vec2 vUV;

    void main(void) {
      vec2 pos = position;
      pos.x *= factor;
      gl_Position = vec4(pos, 0., 1.);
      vec2 pos2 = texPosition;
      pos2.x /= screenRatio;
      pos2 = pos2 + 1.;
      pos2 = pos2 / 2.;
      pos2.y = 1.0 - pos2.y;
      vUV = pos2;
    }
    """

  hexagonFragmentShaderSource: """
    precision mediump float;
    uniform sampler2D sampler;
    uniform float brightnessAdjust;
    varying vec2 vUV;

    #{colourAdjustmentDeclarations}

    void main(void) {
      vec4 raw = texture2D(sampler, vUV);
      brightness += brightnessAdjust;
      #{colourAdjustmentCode}
    }
    """

  bumpVertexShaderSource: """
    attribute vec2 position;
    attribute float r;
    uniform float factor;
    uniform float screenRatio;
    varying vec2 vUV;
    varying float vR;

    void main(void) {
      vec2 pos = position;
      pos.x *= factor;
      gl_Position = vec4(pos, 0., 1.);
      vec2 pos2 = position;
      pos2.x /= screenRatio;
      pos2 = pos2 + 1.;
      pos2 = pos2 / 2.;
      vR = r;
      pos2.y = 1.0 - pos2.y;
      vUV = pos2;
    }
    """

  bumpFragmentShaderSource: """
    precision mediump float;
    uniform sampler2D sampler;
    varying vec2 vUV;
    varying float vR;

    #{colourAdjustmentDeclarations}

    void main(void) {
      vec2 uv = vUV * 2. - 1.;
      uv[0] *= pow(vR, 1.3);
      uv[1] *= pow(vR, 1.3);
      uv = (uv + 1.) / 2.;
      vec4 raw = texture2D(sampler, uv);
      #{colourAdjustmentCode}
    }
    """

  backgroundVertexShaderSource: """
    attribute vec2 position;
    uniform float factor;
    uniform float screenRatio;
    varying vec2 vUV;

    void main(void) {
      gl_Position = vec4(position, 0., 1.);
      vec2 pos2 = position;
      pos2.x /= factor;
      pos2.x /= screenRatio;
      pos2 = pos2 + 1.;
      pos2 = pos2 / 2.;
      pos2.y = 1.0 - pos2.y;
      vUV = pos2;
    }
    """

  backgroundFragmentShaderSource: """
    precision mediump float;
    uniform sampler2D sampler;
    varying vec2 vUV;
    float darkenAmount = 0.6;

    #{colourAdjustmentDeclarations}

    void main(void) {
      vec4 raw = texture2D(sampler, vUV);
      raw = vec4(vec3(raw) - darkenAmount, 1.);
      #{colourAdjustmentCode}
      gl_FragColor = vec4(pixelColour, 1.);
    }
    """

  decalVertexShaderSource: """
    attribute vec2 position;
    uniform float factor;
    uniform float screenRatio;
    uniform mat2 transform;

    void main(void) {
      vec2 pos = position;
      // Rotate by angle
      pos = transform * pos;
      pos.x *= factor;
      gl_Position = vec4(pos, 0., 1.);
    }
    """

  decalFragmentShaderSource: """
    precision mediump float;

    void main(void) {
      gl_FragColor = vec4(0.4, 0.7, 1., 0.2);
    }
    """

  getShader: (type, source) ->
    shader = @GL.createShader(type)
    @GL.shaderSource(shader, source)
    @GL.compileShader(shader)
    unless @GL.getShaderParameter(shader, @GL.COMPILE_STATUS)
      alert("ERROR IN #{if type is @GL.VERTEX_SHADER then 'vertex' else 'fragment'} SHADER : #{@GL.getShaderInfoLog(shader)}")
      return false
    return shader

  resizeCanvas: =>
    @canvas.width = window.innerWidth
    @canvas.height = window.innerHeight
    return

  initCanvas: ->
    @canvas = document.getElementById("canvas")
    @resizeCanvas()
    window.addEventListener 'resize', @resizeCanvas, true
    return true

  initGLContext: ->
    @GL = @canvas.getContext("experimental-webgl", {antialias: true})
    return true

  createNamedShader: (name, attributes, uniforms) ->
    vertexShader = @getShader(@GL.VERTEX_SHADER, this["#{name}VertexShaderSource"])
    fragmentShader = @getShader(@GL.FRAGMENT_SHADER, this["#{name}FragmentShaderSource"])
    shaderProgram = @GL.createProgram()
    @GL.attachShader(shaderProgram, vertexShader)
    @GL.attachShader(shaderProgram, fragmentShader)
    @GL.linkProgram(shaderProgram)

    for varName in attributes
      shaderProgram["_#{varName}"] = @GL.getAttribLocation(shaderProgram, varName)

    for varName in uniforms
      shaderProgram["_#{varName}"] = @GL.getUniformLocation(shaderProgram, varName)

    shaderProgram.use = (fn) =>
      @GL.useProgram(shaderProgram)
      for varName in attributes
        @GL.enableVertexAttribArray(shaderProgram["_#{varName}"])
      fn(shaderProgram)
      for varName in attributes
        @GL.disableVertexAttribArray(shaderProgram["_#{varName}"])
      return

    return shaderProgram

  createVertexAndFaceBuffers: (name, object, triangleVertexData, triangleFacesData) ->
    object.triangleVertexData = triangleVertexData
    object.triangleVertex = @GL.createBuffer()
    @GL.bindBuffer(@GL.ARRAY_BUFFER, object.triangleVertex)
    @GL.bufferData(@GL.ARRAY_BUFFER, new Float32Array(triangleVertexData), @GL.STATIC_DRAW)

    object.triangleFacesData = triangleFacesData
    object.triangleFaces = @GL.createBuffer()
    @GL.bindBuffer(@GL.ELEMENT_ARRAY_BUFFER, object.triangleFaces)
    @GL.bufferData(@GL.ELEMENT_ARRAY_BUFFER, new Uint16Array(triangleFacesData), @GL.STATIC_DRAW)
    return object

  initHexagons: (name, hexagonsHigh, widthToHeight, minR, maxR, zoomFactor) ->
    hexagons = []
    size = 2 / (hexagonsHigh / TAN30)
    fiddle =
      x: 3/10
      y: 3/10 * TAN30 / 2
    offsetX = size * (2 + fiddle.x)
    offsetY = size * (1/(2*TAN30) + fiddle.y)
    for row in [-hexagonsHigh..hexagonsHigh]
      highIndex = hexagonsHigh * widthToHeight * TAN30 / 2
      for col in [-highIndex..highIndex]
        x =
          if Math.abs(row % 2) is 1
            col * (offsetX + size)
          else
            (3 + fiddle.x) * size/2 + col * (offsetX + size)
        y = row * offsetY
        hexagons.push new Hexagon x, y, size, maxR, minR, zoomFactor

    triangleVertexData = []
    triangleFacesData = []
    for hexagon, i in hexagons
      previousVerticiesCount = triangleVertexData.length / 4
      {verticiesData, facesData} = hexagon.data(previousVerticiesCount)
      triangleVertexData.push datum for datum in verticiesData
      triangleFacesData.push datum for datum in facesData

    @createVertexAndFaceBuffers(name, hexagons, triangleVertexData, triangleFacesData)
    return hexagons

  initCircleSegments: (name, segmentCount, radius) ->
    segments = {}
    angleStep = 2 * Math.PI / segmentCount
    angle = 0
    verticies = [[0, 0]]
    for i in [0...segmentCount]
      verticies.push [
        radius * Math.sin(i * angleStep)
        radius * Math.cos(i * angleStep)
      ]
    faces = []
    for i in [1...segmentCount]
      faces.push [0, i, i+1]
    faces.push [0, segmentCount, 1]

    triangleVertexData = []
    for vertex, i in verticies
      triangleVertexData.push vertex[0]
      triangleVertexData.push vertex[1]
      triangleVertexData.push (if i is 0 then INNER_BUMP_R else 1)

    triangleFacesData = []
    for face in faces
      for point in face
        triangleFacesData.push point

    @createVertexAndFaceBuffers(name, segments, triangleVertexData, triangleFacesData)
    return segments

  initBackgroundSquare: (name) ->
    square = {}
    triangleVertexData = [
      -1, -1
      1, -1
      1, 1
      -1, 1
    ]
    triangleFacesData = [
      0, 1, 2
      0, 2, 3
    ]

    @createVertexAndFaceBuffers(name, square, triangleVertexData, triangleFacesData)
    return square

  initDecals: (name, inner) ->
    decals = []
    r =
      if inner
        INNER_RING_RADIUS
      else
        OUTER_RING_RADIUS

    r2 = r - (OUTER_RING_RADIUS - INNER_RING_RADIUS) / 2

    smallDecalCount = 10
    largeDecalCount = 5
    decalCount = ((smallDecalCount + 1) * largeDecalCount) + 1
    angleStep = (Math.PI * 2) / 4 / (decalCount - 1)

    for i in [0...decalCount]
      large = (i % (smallDecalCount + 1) is 0)
      angle = i * angleStep
      if !inner
        angle -= Math.PI/2
      decals.push new Decal r, angle, large
      decals.push new Decal r, angle + Math.PI, large
      if i == 0 || i == decalCount - 1
        decals.push new Decal r2, angle, large
        decals.push new Decal r2, angle + Math.PI, large

    triangleVertexData = []
    triangleFacesData = []
    for decal, i in decals
      previousVerticiesCount = triangleVertexData.length / 2
      {verticiesData, facesData} = decal.data(previousVerticiesCount)
      triangleVertexData.push datum for datum in verticiesData
      triangleFacesData.push datum for datum in facesData

    @createVertexAndFaceBuffers(name, decals, triangleVertexData, triangleFacesData)
    return decals

  initTexture: ->
    # https://dev.opera.com/articles/webgl-post-processing/
    @texture = @GL.createTexture()
    #@GL.pixelStorei(@GL.UNPACK_FLIP_Y_WEBGL, true)
    @GL.bindTexture(@GL.TEXTURE_2D, @texture)
    @GL.texParameteri(@GL.TEXTURE_2D, @GL.TEXTURE_WRAP_S, @GL.CLAMP_TO_EDGE)
    @GL.texParameteri(@GL.TEXTURE_2D, @GL.TEXTURE_WRAP_T, @GL.CLAMP_TO_EDGE)
    @GL.texParameteri(@GL.TEXTURE_2D, @GL.TEXTURE_MIN_FILTER, @GL.NEAREST)
    @GL.texParameteri(@GL.TEXTURE_2D, @GL.TEXTURE_MAG_FILTER, @GL.NEAREST)
    @GL.bindTexture(@GL.TEXTURE_2D, null)

    return

  initElements: ->
    @image = document.getElementsByTagName('img')[0]
    @video = document.getElementsByTagName('video')[0]

  init: ->
    try
      @initCanvas()
      @initGLContext()

      @beginInitShaders?()
      @shaderProgram = @createNamedShader('hexagon', ['position', 'texPosition'], ['factor', 'screenRatio', 'sampler', 'brightnessAdjust'])
      @bumpShaderProgram = @createNamedShader('bump', ['position', 'r'], ['factor', 'screenRatio', 'sampler'])
      @backgroundShaderProgram = @createNamedShader('background', ['position'], ['factor', 'screenRatio', 'sampler'])
      @decalShaderProgram = @createNamedShader('decal', ['position'], ['factor', 'screenRatio', 'transform'])
      @endInitShaders?()

      @beginInitShapes?()
      @bigHexagons = @initHexagons('bigHaxagons', HEXAGONS_HIGH, SCREEN_RATIO, OUTER_RING_RADIUS + RING_WIDTH, Infinity, OUTER_ZOOM_FACTOR)
      @smallHexagons = @initHexagons('smallHexagons', SMALL_HEXAGONS_HIGH, 1, INNER_RING_RADIUS + RING_WIDTH, OUTER_RING_RADIUS, INNER_ZOOM_FACTOR)
      @circleSegments = @initCircleSegments('circleSegments', CIRCLE_SEGMENTS, INNER_RING_RADIUS)
      @backgroundSquare = @initBackgroundSquare('backgroundSquare')
      @innerDecals = @initDecals('innerDecals', true)
      @outerDecals = @initDecals('outerDecals', false)
      @endInitShapes?()

      @initTexture()
      @initElements()
      @GL.clearColor(0.0, 0.0, 0.0, 0.0)
      return true
    catch e
      console.error e.stack
      alert("You are not compatible :(")
      return false

  draw: =>
    @GL.viewport(0.0, 0.0, @canvas.width, @canvas.height)
    @GL.clear(@GL.COLOR_BUFFER_BIT)

    @GL.bindTexture(@GL.TEXTURE_2D, @texture)
    textureSource =
      if @video.loaded and !@video.paused
        @video
      else
        @image
    @GL.texImage2D(@GL.TEXTURE_2D, 0, @GL.RGBA, @GL.RGBA, @GL.UNSIGNED_BYTE, textureSource)

    @backgroundShaderProgram.use =>
      @GL.uniform1f(@backgroundShaderProgram._factor, @canvas.height / @canvas.width)
      @GL.uniform1f(@backgroundShaderProgram._screenRatio, SCREEN_RATIO)
      @GL.uniform1i(@backgroundShaderProgram._sampler, 0)

      @GL.bindBuffer(@GL.ARRAY_BUFFER, @backgroundSquare.triangleVertex)
      @GL.vertexAttribPointer(@backgroundShaderProgram._position, 2, @GL.FLOAT, false, 4*(2+0), 0)

      @GL.bindBuffer(@GL.ELEMENT_ARRAY_BUFFER, @backgroundSquare.triangleFaces)
      @GL.drawElements(@GL.TRIANGLES, @backgroundSquare.triangleFacesData.length, @GL.UNSIGNED_SHORT, 0)


    @shaderProgram.use =>
      @GL.uniform1f(@shaderProgram._factor, @canvas.height / @canvas.width)
      @GL.uniform1f(@shaderProgram._screenRatio, SCREEN_RATIO)
      @GL.uniform1i(@shaderProgram._sampler, 0)


      for hexagons, i in [@bigHexagons, @smallHexagons]
        @GL.uniform1f(@shaderProgram._brightnessAdjust, (if i == 0 then -0.14 else -0.06))
        @GL.bindBuffer(@GL.ARRAY_BUFFER, hexagons.triangleVertex)
        @GL.vertexAttribPointer(@shaderProgram._position, 2, @GL.FLOAT, false, 4*(2+2), 0)
        @GL.vertexAttribPointer(@shaderProgram._texPosition, 2, @GL.FLOAT, false, 4*(2+2), 2*4)

        @GL.bindBuffer(@GL.ELEMENT_ARRAY_BUFFER, hexagons.triangleFaces)
        @GL.drawElements(@GL.TRIANGLES, hexagons.triangleFacesData.length, @GL.UNSIGNED_SHORT, 0)

    @bumpShaderProgram.use =>
      @GL.uniform1f(@bumpShaderProgram._factor, @canvas.height / @canvas.width)
      @GL.uniform1f(@bumpShaderProgram._screenRatio, SCREEN_RATIO)
      @GL.uniform1i(@bumpShaderProgram._sampler, 0)
      @GL.bindBuffer(@GL.ARRAY_BUFFER, @circleSegments.triangleVertex)
      @GL.vertexAttribPointer(@bumpShaderProgram._position, 2, @GL.FLOAT, false, 4*(2+1), 0)
      @GL.vertexAttribPointer(@bumpShaderProgram._r, 1, @GL.FLOAT, false, 4*(2+1), 4*2)

      @GL.bindBuffer(@GL.ELEMENT_ARRAY_BUFFER, @circleSegments.triangleFaces)
      @GL.drawElements(@GL.TRIANGLES, @circleSegments.triangleFacesData.length, @GL.UNSIGNED_SHORT, 0)

    @decalShaderProgram.use =>
      @GL.uniform1f(@decalShaderProgram._factor, @canvas.height / @canvas.width)
      @GL.uniform1f(@decalShaderProgram._screenRatio, SCREEN_RATIO)
      for decals, i in [@innerDecals, @outerDecals]
        currentTime = Date.now()
        intervalDuration = ANIMATION_DURATION
        intervalCount = ANIMATION_INTERVAL
        intervalCount = Math.max(Math.ceil(intervalCount / 2) * 2, 2)
        interval = Math.floor(currentTime / intervalDuration)
        step = interval % intervalCount
        if step == 0
          # Animate
          position = (currentTime % intervalDuration) / (intervalDuration - 1)
          rotationAmount = Math.sin(position * Math.PI / 2)
        else if step == intervalCount / 2
          # Animate
          position = (currentTime % intervalDuration) / (intervalDuration - 1)
          rotationAmount = Math.sin((1 - position) * Math.PI / 2)
        else if step < intervalCount / 2
          rotationAmount = 1
        else
          rotationAmount = 0
        angle = rotationAmount * (if i == 0 then Math.PI/4 else -Math.PI/4)
        @GL.uniformMatrix2fv(@decalShaderProgram._transform, @GL.FALSE, new Float32Array([Math.cos(angle), -Math.sin(angle), Math.sin(angle), Math.cos(angle)]))
        @GL.bindBuffer(@GL.ARRAY_BUFFER, decals.triangleVertex)
        @GL.vertexAttribPointer(@decalShaderProgram._position, 2, @GL.FLOAT, false, 4*(2+0), 0)

        @GL.bindBuffer(@GL.ELEMENT_ARRAY_BUFFER, decals.triangleFaces)
        @GL.drawElements(@GL.TRIANGLES, decals.triangleFacesData.length, @GL.UNSIGNED_SHORT, 0)

    @GL.flush()

    window?.requestAnimationFrame(@draw)
    return

  run: ->
    @draw()
    navigator.getUserMedia ||= navigator.webkitGetUserMedia
    navigator.getUserMedia ||= navigator.mozGetUserMedia
    navigator.getUserMedia ||= navigator.msGetUserMedia
    window.URL ?= window.webkitURL
    window.URL ?= window.mozURL
    window.URL ?= window.msURL

    navigator.getUserMedia {video: true}, (localMediaStream) =>
      if @video.mozSrcObject isnt undefined
        @video.mozSrcObject = localMediaStream
      else
        @video.src = window.URL?.createObjectURL(localMediaStream) ? localMediaStream
      @video.loaded = true
      @video.play()
    , -> alert("GUM fail.")

  start: =>
    @init() and @run()


if window?
  window.APP = APP = new App
  window.addEventListener 'DOMContentLoaded', APP.start, false
else
  module.exports = {App, SCREEN_RATIO}

      getPseudoColumns: (data, options) ->
        data = data.filter (s) -> s.type is 'column'

        pseudoColumns = {}
        keys = []
        data.forEach (series) ->
          inAStack = false
          options.stacks.forEach (stack, index) ->
            if series.id? and series.id in stack.series
              pseudoColumns[series.name + series.index] = index
              keys.push(index) unless index in keys
              inAStack = true

          if inAStack is false
            i = pseudoColumns[series.name + series.index] = index = keys.length
            keys.push(i)

        return {pseudoColumns, keys}

      getBestColumnWidth: (dimensions, seriesData, options) ->
        return 10 unless seriesData and seriesData.length isnt 0

        {pseudoColumns, keys} = this.getPseudoColumns(seriesData, options)

        # +2 because abscissas will be extended to one more row at each end
        n = seriesData[0].values.length + 2
        seriesCount = keys.length
        gap = 0 # space between two rows
        avWidth = dimensions.width - dimensions.left - dimensions.right

        return parseInt(Math.max((avWidth - (n - 1)*gap) / (n*seriesCount), 5))

      getColumnAxis: (data, columnWidth, options, hAlign) ->
        {pseudoColumns, keys} = this.getPseudoColumns(data, options)

        x1 = d3.scale.ordinal()
          .domain(keys)
          .rangeBands([0, keys.length * columnWidth], 0)

        delta = (index) ->
          if hAlign is 'left'
            return 0
          else if hAlign is 'center'
            return columnWidth/2


        return (s) ->
          return 0 unless pseudoColumns[s.name + s.index]?
          index = pseudoColumns[s.name + s.index]
          return x1(index) - keys.length*columnWidth/2 + delta(index)


      drawColumns: (svg, axes, data, columnWidth, options, handlers) ->
        data = data.filter (s) -> s.type is 'column'

        x1 = this.getColumnAxis(data, columnWidth, options, 'left')

        data.forEach (s) -> s.xOffset = x1(s) + columnWidth*.5

        colGroup = svg.select('.content').selectAll('.columnGroup')
          .data(data)
          .enter().append("g")
            .attr('class', (s) -> 'columnGroup series_' + s.index)
            .style('stroke', (s) -> s.color)
            .style('fill', (s) -> s.color)
            .style('fill-opacity', 0.8)
            .attr('transform', (s) -> "translate(" + x1(s) + ",0)")
            .on('mouseover', (series) ->
              target = d3.select(d3.event.target)

              handlers.onMouseOver?(svg, {
                series: series
                x: target.attr('x')
                y: axes[series.axis + 'Scale'](target.datum().y0 + target.datum().y)
                datum: target.datum()
              })
            )
            .on('mouseout', (d) ->
              d3.select(d3.event.target).attr('r', 2)
              handlers.onMouseOut?(svg)
            )

        colGroup.selectAll("rect")
          .data (d) -> d.values
          .enter().append("rect")
            .style({
              'stroke-width': (d) -> if d.y is 0 then '0px' else '1px'
              'fill-opacity': (d) -> if d.y is 0 then 0 else 0.7
            })

            .attr(
              width: columnWidth
              x: (d) -> axes.xScale(d.x)
              height: (d) ->
                return axes[d.axis + 'Scale'].range()[0] if d.y is 0
                return Math.abs(axes[d.axis + 'Scale'](d.y0 + d.y) - axes[d.axis + 'Scale'](d.y0))
              y: (d) ->
                if d.y is 0 then 0 else axes[d.axis + 'Scale'](Math.max(0, d.y0 + d.y))
            )

        return this
